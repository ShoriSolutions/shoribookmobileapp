// ================================================================
// Shorivo -- dispatch-emails Edge Function (Resend transport).
//
// Serverless drain of public.email_outbox via Resend's HTTP API. This is the
// Deno equivalent of backend/nodemailer/email-dispatcher.mjs -- same queue,
// same claim/mark RPCs -- so you can send ALL Shorivo email (booking reminders,
// trial notices, new-message notices, security alerts) without hosting a
// separate Node/Nodemailer worker. Run either dispatcher; they claim rows
// atomically (claim_outbox_emails uses FOR UPDATE SKIP LOCKED), so they never
// double-send.
//
// Flow (service role): check the daily budget -> claim_outbox_emails(budget)
// -> POST each to Resend -> mark_outbox_sent / mark_outbox_failed (requeues up
// to 5 attempts, then fails) / release_outbox_email (quota or rate limit hit:
// back to the queue without spending a retry).
//
// Resend limits (free plan): 100 emails/day, 3,000/month, 10 requests/second,
// all counted per Resend team -- so the website and Supabase Auth's SMTP emails
// (sign-up, password reset, staff invites) share the same allowance. Before
// sending we read the team's real usage over the last 24 hours from Resend and
// only send while it stays under RESEND_DAILY_LIMIT minus RESEND_DAILY_RESERVE
// (the reserve is headroom for Auth emails, which can't be held back). Emails
// over budget stay queued for the next run. 95/day keeps a 31-day month under
// 3,000. On a paid plan, raise RESEND_DAILY_LIMIT.
//
// Deploy:   supabase functions deploy dispatch-emails --no-verify-jwt
// Schedule: invoke every minute (pg_cron + net.http_post), alongside
//           process-reminders, which enqueues due reminders into the outbox.
//
// Secrets (Edge Function env -- never in the DB or the app):
//   RESEND_API_KEY        -- Resend API key (server only)
//   EMAIL_FROM            -- e.g. "Shorivo <contact@shorisolutions.com>" (must
//                            be a verified Resend sender/domain)
//   RESEND_DAILY_LIMIT    -- optional, default 95
//   RESEND_DAILY_RESERVE  -- optional, default 15
//   (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are injected by the platform.)
// ================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FROM = Deno.env.get("EMAIL_FROM") ?? "Shorivo <contact@shorisolutions.com>";
const RESEND_KEY = Deno.env.get("RESEND_API_KEY");
const BATCH = 50;
const DAILY_LIMIT = intEnv("RESEND_DAILY_LIMIT", 95);
const DAILY_RESERVE = intEnv("RESEND_DAILY_RESERVE", 15);
// ~4 requests/second: well under Resend's 10/s, which the website shares.
const SEND_GAP_MS = 250;

interface OutboxRow {
  id: string;
  to_email: string;
  subject: string;
  html: string;
}

interface SendResult {
  ok: boolean;
  status?: number;
  error?: string;
}

function intEnv(name: string, fallback: number): number {
  const raw = Deno.env.get(name);
  const n = raw ? Number(raw) : NaN;
  return Number.isFinite(n) && n >= 0 ? Math.floor(n) : fallback;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// Resend timestamps look like "2026-08-15 00:36:07.058+00".
function parseTs(s: string): number {
  return Date.parse(s.replace(" ", "T").replace(/([+-]\d\d)$/, "$1:00"));
}

// Emails the whole Resend team sent in the last 24 hours, from Resend's list
// endpoint. One page of 100 is enough: a full page means we're at the cap
// anyway. Returns null if Resend can't be read.
async function teamSentLast24h(): Promise<number | null> {
  try {
    const r = await fetch("https://api.resend.com/emails?limit=100", {
      headers: { Authorization: `Bearer ${RESEND_KEY}` },
    });
    if (!r.ok) return null;
    const body = await r.json();
    const since = Date.now() - 24 * 60 * 60 * 1000;
    let n = 0;
    for (const e of body.data ?? []) {
      const t = e.created_at ? parseTs(e.created_at) : NaN;
      if (!(t >= since)) continue;
      // Every recipient counts as one email toward the quota.
      n += (e.to?.length ?? 1) + (e.cc?.length ?? 0) + (e.bcc?.length ?? 0);
    }
    return n;
  } catch {
    return null;
  }
}

async function sendViaResend(row: OutboxRow): Promise<SendResult> {
  try {
    const r = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: FROM,
        to: row.to_email,
        subject: row.subject,
        html: row.html,
      }),
    });
    if (r.ok) return { ok: true, status: r.status };
    return { ok: false, status: r.status, error: `resend ${r.status}: ${await r.text()}` };
  } catch (e) {
    return { ok: false, error: String(e) };
  }
}

Deno.serve(async () => {
  // Check the key BEFORE claiming so an unconfigured deploy doesn't burn the
  // retry budget on every row (claim increments attempts).
  if (!RESEND_KEY) return json({ error: "RESEND_API_KEY not set" }, 501);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  // This runs every minute: with nothing queued, don't call Resend at all.
  const { count: pending } = await supabase
    .from("email_outbox")
    .select("id", { count: "exact", head: true })
    .eq("status", "pending");
  if (!pending) return json({ pending: 0, claimed: 0, sent: 0, failed: 0 });

  // If Resend can't be read, fall back to what this queue sent (misses the
  // website and Auth emails, but still caps the app's own sending).
  let used = await teamSentLast24h();
  if (used === null) {
    const { count } = await supabase
      .from("email_outbox")
      .select("id", { count: "exact", head: true })
      .eq("status", "sent")
      .gte("sent_at", new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());
    used = count ?? 0;
  }
  const budget = Math.max(0, DAILY_LIMIT - DAILY_RESERVE - used);
  if (budget === 0) {
    return json({ pending, used24h: used, budget, claimed: 0, sent: 0, failed: 0, held: "daily budget reached" });
  }

  const { data, error } = await supabase.rpc("claim_outbox_emails", {
    p_limit: Math.min(BATCH, budget),
  });
  if (error) return json({ error: `claim failed: ${error.message}` }, 500);

  const rows = (data ?? []) as OutboxRow[];
  let sent = 0;
  let failed = 0;
  let held: string | undefined;
  for (let i = 0; i < rows.length; i++) {
    if (i > 0) await sleep(SEND_GAP_MS);
    const res = await sendViaResend(rows[i]);
    if (res.ok) {
      await supabase.rpc("mark_outbox_sent", { p_id: rows[i].id });
      sent++;
      continue;
    }
    if (res.status === 429) {
      // Daily/monthly quota or rate limit: put this email and the rest of the
      // batch back in the queue without spending a retry; next run tries again.
      for (const r of rows.slice(i)) {
        await supabase.rpc("release_outbox_email", { p_id: r.id });
      }
      held = res.error;
      break;
    }
    // Requeues (up to 5 attempts) or marks 'failed'.
    await supabase.rpc("mark_outbox_failed", {
      p_id: rows[i].id,
      p_error: res.error ?? "unknown",
    });
    failed++;
  }

  return json({ pending, used24h: used, budget, claimed: rows.length, sent, failed, ...(held ? { held } : {}) });
});
