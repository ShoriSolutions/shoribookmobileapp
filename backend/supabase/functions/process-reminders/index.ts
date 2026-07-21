// ============================================================================
// process-reminders — Supabase Edge Function
//
// Runs on a schedule (cron, e.g. every minute) and dispatches due reminders.
// It is the ONLY place notifications are sent; the booking workflow just
// enqueues rows in reminder_queue (see 20260714000000_reminder_system.sql).
//
// Deploy:   supabase functions deploy process-reminders --no-verify-jwt
// Secrets:  supabase secrets set RESEND_API_KEY=... EMAIL_FROM="ShoriBooks <noreply@yourdomain>"
//           (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are provided automatically)
// Schedule: a cron (pg_cron + net.http_post) that invokes it every minute.
//
// Email is implemented via Resend. Push (FCM/APNs) and the OFFICIAL WhatsApp
// Business Platform remain stubs until those providers are configured; email
// is the fallback so reminders still go out.
// ============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const BATCH_SIZE = 100;
const MAX_RETRIES = 3;

interface NotificationProvider {
  readonly channel: "push" | "email" | "whatsapp" | "sms";
  send(to: Recipient, subject: string, message: string): Promise<SendResult>;
}
interface Recipient { userId: string | null; email?: string; phone?: string; }
interface SendResult { ok: boolean; providerStatus?: string; error?: string; }

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

// ── Resend email ────────────────────────────────────────────────────────────
async function sendEmail(
  to: string,
  subject: string,
  html: string,
): Promise<SendResult> {
  const key = Deno.env.get("RESEND_API_KEY");
  if (!key) return { ok: false, error: "RESEND_API_KEY not set" };
  const from = Deno.env.get("EMAIL_FROM") ??
    "ShoriBooks <noreply@shorisolutions.com>";
  try {
    const r = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ from, to, subject, html }),
    });
    if (r.ok) return { ok: true, providerStatus: String(r.status) };
    return { ok: false, error: `resend ${r.status}: ${await r.text()}` };
  } catch (e) {
    return { ok: false, error: String(e) };
  }
}

const pushProvider: NotificationProvider = {
  channel: "push",
  async send(_to, _subject, _message) {
    // TODO: send via FCM/APNs using stored device tokens.
    return { ok: false, error: "push provider not configured" };
  },
};
const emailProvider: NotificationProvider = {
  channel: "email",
  async send(to, subject, message) {
    if (!to.email) return { ok: false, error: "no email address" };
    return sendEmail(to.email, subject, `<p>${escapeHtml(message)}</p>`);
  },
};
const whatsappProvider: NotificationProvider = {
  channel: "whatsapp",
  async send(_to, _subject, _message) {
    // TODO: OFFICIAL WhatsApp Business Platform only (Meta Cloud / Twilio /
    // 360dialog). Official APIs only.
    return { ok: false, error: "whatsapp provider not connected" };
  },
};
const providers: Record<string, NotificationProvider> = {
  push: pushProvider,
  email: emailProvider,
  whatsapp: whatsappProvider,
};

// Fallback order when a channel fails (spec: WhatsApp → Push → Email).
const FALLBACK: Record<string, string[]> = {
  whatsapp: ["push", "email"],
  push: ["email"],
  email: [],
  sms: ["push", "email"],
};

const DEFAULT_TEMPLATE =
  "Hi {{customer_name}}, this is a reminder of your {{service_name}} " +
  "appointment with {{business_name}} on {{date}} at {{time}}. " +
  "Ref: {{booking_reference}}";

function renderTemplate(tpl: string, ctx: Record<string, string>): string {
  return tpl.replace(/\{\{(\w+)\}\}/g, (_, k) => ctx[k] ?? "");
}

// ── Trial-ending reminders (7 / 3 / 1 days before trial_ends_at) ─────────────
// Deduped via trial_reminder_log so each (business, offset) fires once.
// deno-lint-ignore no-explicit-any
async function processTrialReminders(supabase: any): Promise<number> {
  const OFFSETS = [7, 3, 1];
  const now = new Date();
  let sent = 0;

  for (const days of OFFSETS) {
    const cutoff = new Date(now.getTime() + days * 86_400_000).toISOString();
    const { data: bizs } = await supabase
      .from("businesses")
      .select("id, name, owner_id, trial_ends_at, auto_renew")
      .eq("subscription_status", "trialing")
      .gt("trial_ends_at", now.toISOString())
      .lte("trial_ends_at", cutoff);

    for (const b of bizs ?? []) {
      // Already notified for this offset?
      const { data: logged } = await supabase
        .from("trial_reminder_log")
        .select("id")
        .eq("business_id", b.id)
        .eq("days_before", days)
        .maybeSingle();
      if (logged) continue;

      const { data: owner } = await supabase
        .from("profiles")
        .select("email, full_name")
        .eq("id", b.owner_id)
        .maybeSingle();
      const email = owner?.email as string | undefined;
      if (!email) continue; // no address; re-check next run once one exists

      const name = (owner?.full_name as string | undefined)?.split(" ")[0] ??
        "there";
      const ends = new Date(b.trial_ends_at);
      const endLabel = new Intl.DateTimeFormat("en-US", {
        month: "short",
        day: "numeric",
      }).format(ends);
      const dayWord = days === 1 ? "day" : "days";
      const willRenew = b.auto_renew === true;
      const subject = `Your ShoriBooks trial ends in ${days} ${dayWord}`;
      const body = willRenew
        ? `Hi ${name}, your free trial for ${b.name} ends ` +
          `on ${endLabel} (${days} ${dayWord} away). Your plan will renew ` +
          `automatically so there's nothing to do — manage or cancel anytime ` +
          `in ShoriBooks under More → Subscription.`
        : `Hi ${name}, your free trial for ${b.name} ends on ${endLabel} ` +
          `(${days} ${dayWord} away). To keep your bookings, clients and ` +
          `schedule, choose a plan in ShoriBooks under More → Subscription ` +
          `before it ends.`;

      const res = await sendEmail(email, subject, `<p>${escapeHtml(body)}</p>`);
      if (res.ok) {
        await supabase
          .from("trial_reminder_log")
          .insert({ business_id: b.id, days_before: days });
        sent++;
      }
    }
  }
  return sent;
}

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: due, error } = await supabase
    .from("reminder_queue")
    .select("id, booking_id, business_id, user_id, channel, retry_count")
    .eq("status", "pending")
    .lte("scheduled_for", new Date().toISOString())
    .lt("retry_count", MAX_RETRIES)
    .order("scheduled_for", { ascending: true })
    .limit(BATCH_SIZE);
  if (error) return new Response(error.message, { status: 500 });

  const settingsCache = new Map<string, { reminder_template?: string } | null>();
  async function settingsFor(businessId: string) {
    if (settingsCache.has(businessId)) return settingsCache.get(businessId);
    const { data } = await supabase
      .from("notification_settings")
      .select("reminder_template")
      .eq("business_id", businessId)
      .maybeSingle();
    settingsCache.set(businessId, data);
    return data;
  }

  let processed = 0;
  for (const row of due ?? []) {
    // Build the message + recipient from the appointment.
    const { data: appt } = await supabase
      .from("appointments")
      .select(
        "id, customer_name, customer_email, customer_timezone, start_time, " +
          "services(name), businesses(name, timezone)",
      )
      .eq("id", row.booking_id)
      .maybeSingle();

    if (!appt) {
      await supabase.from("reminder_queue").update({
        status: "failed",
        failed_at: new Date().toISOString(),
        error_message: "appointment not found",
      }).eq("id", row.id);
      processed++;
      continue;
    }

    // deno-lint-ignore no-explicit-any
    const a = appt as any;
    const tz = a.businesses?.timezone ?? "America/Barbados";
    const start = new Date(a.start_time);
    const date = new Intl.DateTimeFormat("en-US", {
      timeZone: tz,
      weekday: "short",
      month: "short",
      day: "numeric",
    }).format(start);
    const time = new Intl.DateTimeFormat("en-US", {
      timeZone: tz,
      hour: "numeric",
      minute: "2-digit",
    }).format(start);

    const settings = await settingsFor(row.business_id);
    const tpl = settings?.reminder_template ?? DEFAULT_TEMPLATE;
    let message = renderTemplate(tpl, {
      customer_name: a.customer_name ?? "there",
      service_name: a.services?.name ?? "appointment",
      business_name: a.businesses?.name ?? "us",
      date,
      time,
      booking_reference: String(a.id).slice(0, 8).toUpperCase(),
    });

    // When the customer booked from a different zone, spell out both times
    // so the reminder is never off by an hour in their head.
    const custTz = a.customer_timezone as string | undefined;
    if (custTz && custTz !== tz) {
      const custTime = new Intl.DateTimeFormat("en-US", {
        timeZone: custTz,
        hour: "numeric",
        minute: "2-digit",
      }).format(start);
      if (custTime !== time) {
        const bizPlace = tz.split("/").pop()?.replaceAll("_", " ") ?? tz;
        message += `\n\nBusiness time: ${time} (${bizPlace}) · ` +
          `Your time: ${custTime}`;
      }
    }
    const subject = `Reminder: ${a.services?.name ?? "appointment"} at ` +
      `${a.businesses?.name ?? "your appointment"}`;
    const recipient: Recipient = {
      userId: row.user_id,
      email: a.customer_email ?? undefined,
    };

    const order = [row.channel, ...(FALLBACK[row.channel] ?? [])];
    let sent = false;
    let lastError = "";
    for (const ch of order) {
      const provider = providers[ch];
      if (!provider) continue;
      const res = await provider.send(recipient, subject, message);
      if (res.ok) {
        await supabase.from("reminder_queue").update({
          status: "sent",
          sent_at: new Date().toISOString(),
          channel: ch,
        }).eq("id", row.id);
        sent = true;
        break;
      }
      lastError = res.error ?? "send failed";
    }

    if (!sent) {
      const retry = (row.retry_count ?? 0) + 1;
      await supabase.from("reminder_queue").update({
        status: retry >= MAX_RETRIES ? "failed" : "pending",
        retry_count: retry,
        failed_at: new Date().toISOString(),
        error_message: lastError,
      }).eq("id", row.id);
    }
    processed++;
  }

  // Trial-ending notices (7/3/1 days out), independent of the queue above.
  const trialReminders = await processTrialReminders(supabase);

  return new Response(JSON.stringify({ processed, trialReminders }), {
    headers: { "content-type": "application/json" },
  });
});
