// ============================================================================
// process-reminders — Supabase Edge Function (skeleton)
//
// Runs on a schedule (cron, e.g. every minute) and dispatches due reminders.
// It is the ONLY place notifications are sent; the booking workflow just
// enqueues rows in reminder_queue (see 20260714000000_reminder_system.sql).
//
// Deploy:   supabase functions deploy process-reminders
// Schedule: create a cron that invokes this function every minute, e.g. via
//           pg_cron + net.http_post, or Supabase scheduled functions.
//
// Secrets (Edge Function env — NEVER in the DB or in Flutter):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//   PUSH_* , EMAIL_* , and the WhatsApp provider creds, e.g.
//   WHATSAPP_PROVIDER=meta_cloud|twilio|360dialog and that provider's tokens.
//
// WhatsApp: OFFICIAL WhatsApp Business Platform ONLY (Meta Cloud API / Twilio /
// 360dialog). Never personal accounts, unofficial/reverse-engineered APIs, or
// browser automation. If a business has no connected official account, the
// 'whatsapp' channel is simply never enqueued (see generate_reminders), so we
// won't receive rows for it here.
// ============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const BATCH_SIZE = 100;
const MAX_RETRIES = 3;

// ── Provider abstraction ────────────────────────────────────────────────────
// Booking logic never calls these directly. Add a provider by implementing
// this interface and registering it below — no change to booking code.
interface NotificationProvider {
  readonly channel: "push" | "email" | "whatsapp" | "sms";
  send(to: Recipient, message: string): Promise<SendResult>;
}
interface Recipient { userId: string | null; email?: string; phone?: string; }
interface SendResult { ok: boolean; providerStatus?: string; error?: string; }

// TODO: implement each provider against your chosen service (env-configured).
const pushProvider: NotificationProvider = {
  channel: "push",
  async send(_to, _message) {
    // TODO: send via FCM/APNs using stored device tokens.
    return { ok: false, error: "push provider not configured" };
  },
};
const emailProvider: NotificationProvider = {
  channel: "email",
  async send(_to, _message) {
    // TODO: send via your email provider (Resend/SendGrid/SES…).
    return { ok: false, error: "email provider not configured" };
  },
};
const whatsappProvider: NotificationProvider = {
  channel: "whatsapp",
  async send(_to, _message) {
    // TODO: send via the OFFICIAL WhatsApp Business Platform provider selected
    // in env (Meta Cloud API / Twilio / 360dialog). Official APIs only.
    return { ok: false, error: "whatsapp provider not connected" };
  },
};
// SMS: architecture only for the MVP.
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

function renderTemplate(tpl: string, ctx: Record<string, string>): string {
  return tpl.replace(/\{\{(\w+)\}\}/g, (_, k) => ctx[k] ?? "");
}

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Due, still-pending reminders under the retry cap.
  const { data: due, error } = await supabase
    .from("reminder_queue")
    .select("id, booking_id, business_id, user_id, channel, retry_count")
    .eq("status", "pending")
    .lte("scheduled_for", new Date().toISOString())
    .lt("retry_count", MAX_RETRIES)
    .order("scheduled_for", { ascending: true })
    .limit(BATCH_SIZE);
  if (error) return new Response(error.message, { status: 500 });

  let processed = 0;
  for (const row of due ?? []) {
    // TODO: fetch booking + business + customer + service + staff, build the
    // placeholder context and the recipient, then render the template:
    //   const message = renderTemplate(tpl, ctx);
    const ctx: Record<string, string> = {};
    const message = renderTemplate("", ctx);
    const recipient: Recipient = { userId: row.user_id };

    // Try the requested channel, then fall back through enabled channels.
    const order = [row.channel, ...(FALLBACK[row.channel] ?? [])];
    let sent = false;
    let lastError = "";
    for (const ch of order) {
      const provider = providers[ch];
      if (!provider) continue;
      const res = await provider.send(recipient, message);
      if (res.ok) {
        await supabase.from("reminder_queue").update({
          status: "sent",
          sent_at: new Date().toISOString(),
          channel: ch, // record the channel that actually delivered it
        }).eq("id", row.id);
        // TODO (fallback audit): if ch !== row.channel, also insert a row
        // recording the fallback attempt.
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

  return new Response(JSON.stringify({ processed }), {
    headers: { "content-type": "application/json" },
  });
});

// Delivery/read receipts: register a separate webhook Edge Function with each
// provider to flip status → 'delivered' / 'read' as callbacks arrive.
