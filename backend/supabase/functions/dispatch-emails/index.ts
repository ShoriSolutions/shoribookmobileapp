// ================================================================
// Shorivo -- dispatch-emails Edge Function (Resend transport).
//
// Serverless drain of public.email_outbox via Resend's HTTP API. This is the
// Deno equivalent of backend/nodemailer/email-dispatcher.mjs -- same queue,
// same claim/mark RPCs -- so you can send ALL Shorivo email (booking reminders,
// trial notices, new-message notices, staff invites) without hosting a separate
// Node/Nodemailer worker. Run either dispatcher; they claim rows atomically
// (claim_outbox_emails uses FOR UPDATE SKIP LOCKED), so they never double-send.
//
// Flow (service role): claim_outbox_emails(limit) -> POST each to Resend ->
// mark_outbox_sent / mark_outbox_failed (requeues up to 5 attempts, then fails).
//
// Deploy:   supabase functions deploy dispatch-emails --no-verify-jwt
// Schedule: invoke every minute (pg_cron + net.http_post, or Supabase
//           scheduled functions) -- alongside process-reminders, which is the
//           producer that enqueues due reminders into the outbox.
//
// Secrets (Edge Function env -- never in the DB or the app):
//   RESEND_API_KEY   -- Resend API key (server only)
//   EMAIL_FROM       -- e.g. "Shorivo <contact@shorisolutions.com>" (must be a
//                       verified Resend sender/domain)
//   (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are injected by the platform.)
// ================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FROM = Deno.env.get("EMAIL_FROM") ?? "Shorivo <contact@shorisolutions.com>";
const RESEND_KEY = Deno.env.get("RESEND_API_KEY");
const BATCH = 50;

interface OutboxRow {
  id: string;
  to_email: string;
  subject: string;
  html: string;
}

async function sendViaResend(
  row: OutboxRow,
): Promise<{ ok: boolean; error?: string }> {
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
    if (r.ok) return { ok: true };
    return { ok: false, error: `resend ${r.status}: ${await r.text()}` };
  } catch (e) {
    return { ok: false, error: String(e) };
  }
}

Deno.serve(async () => {
  // Check the key BEFORE claiming so an unconfigured deploy doesn't burn the
  // retry budget on every row (claim increments attempts).
  if (!RESEND_KEY) {
    return new Response(
      JSON.stringify({ error: "RESEND_API_KEY not set" }),
      { status: 501, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const { data, error } = await supabase.rpc("claim_outbox_emails", {
    p_limit: BATCH,
  });
  if (error) {
    return new Response(
      JSON.stringify({ error: `claim failed: ${error.message}` }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const rows = (data ?? []) as OutboxRow[];
  let sent = 0;
  let failed = 0;
  for (const row of rows) {
    const res = await sendViaResend(row);
    if (res.ok) {
      await supabase.rpc("mark_outbox_sent", { p_id: row.id });
      sent++;
    } else {
      // Requeues (up to 5 attempts) or marks 'failed'.
      await supabase.rpc("mark_outbox_failed", {
        p_id: row.id,
        p_error: res.error ?? "unknown",
      });
      failed++;
    }
  }

  return new Response(
    JSON.stringify({ claimed: rows.length, sent, failed }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
