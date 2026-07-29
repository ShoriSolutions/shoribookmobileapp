// ============================================================================
// process-reminders — Supabase Edge Function
//
// Runs on a schedule (cron, e.g. every minute) and dispatches due reminders.
// It is the ONLY place notifications are sent; the booking workflow just
// enqueues rows in reminder_queue (see 20260714000000_reminder_system.sql).
//
// Deploy:   supabase functions deploy process-reminders --no-verify-jwt
// Secrets:  none needed for email (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY
//           are provided automatically).
// Schedule: a cron (pg_cron + net.http_post) that invokes it every minute.
//
// Email is ENQUEUED into public.email_outbox and SENT by the Node/Nodemailer
// dispatcher (backend/nodemailer/email-dispatcher.mjs) — Deno can't run
// Nodemailer. Push (FCM/APNs) and the OFFICIAL WhatsApp Business Platform
// remain stubs until configured; email is the fallback so reminders go out.
// ============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const BATCH_SIZE = 100;
const MAX_RETRIES = 3;

// Service-role client (also used to enqueue email into the outbox).
const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

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

// ── Email -> outbox (sent by the Node/Nodemailer dispatcher) ─────────────────
// Deno can't run Nodemailer, so we enqueue here; the Node backend drains
// public.email_outbox and does the actual SMTP send. `dedupeKey` prevents a
// double-enqueue if this cron run overlaps.
async function enqueueEmail(
  to: string,
  subject: string,
  html: string,
  category = "general",
  dedupeKey?: string,
): Promise<SendResult> {
  if (!to) return { ok: false, error: "no email address" };
  const { error } = await admin.from("email_outbox").insert({
    to_email: to,
    subject,
    html,
    category,
    dedupe_key: dedupeKey ?? null,
  });
  if (error) {
    // Unique dedupe violation -> already queued; treat as success.
    // deno-lint-ignore no-explicit-any
    if ((error as any).code === "23505") {
      return { ok: true, providerStatus: "deduped" };
    }
    return { ok: false, error: error.message };
  }
  return { ok: true, providerStatus: "queued" };
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
    return enqueueEmail(
      to.email,
      subject,
      `<p>${escapeHtml(message)}</p>`,
      "booking_reminder",
    );
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

      const res = await enqueueEmail(
        email,
        subject,
        `<p>${escapeHtml(body)}</p>`,
        "trial",
        `trial:${b.id}:${days}`,
      );
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

// New-message email notices for offline users. The RPC claims + de-dupes
// atomically (grace period, mute-aware, cooldown); we enqueue each into the
// outbox for the Node/Nodemailer dispatcher to send.
// deno-lint-ignore no-explicit-any
async function processMessageEmails(supabase: any): Promise<number> {
  const { data, error } = await supabase.rpc("claim_message_email_targets", {
    p_grace_minutes: 3,
    p_cooldown_minutes: 60,
  });
  if (error || !data) return 0;
  let queued = 0;
  for (const t of data) {
    const first = ((t.recipient_name as string) ?? "there").split(" ")[0];
    const extra = (t.unread as number) > 1 ? ` (${t.unread} new messages)` : "";
    const preview = t.preview ? `: "${escapeHtml(t.preview as string)}"` : "";
    const subject = `New message from ${t.other_name}`;
    const html = `<p>Hi ${escapeHtml(first)}, you have a new message from ` +
      `${escapeHtml(t.other_name as string)} on Shorivo${extra}${preview}. ` +
      `Open the app to reply.</p>`;
    const res = await enqueueEmail(
      t.recipient_email as string,
      subject,
      html,
      "message",
    );
    if (res.ok) queued++;
  }
  return queued;
}

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: due, error } = await supabase
    .from("reminder_queue")
    .select(
      "id, booking_id, business_id, user_id, channel, retry_count, kind, " +
        "payload, waitlist_entry_id",
    )
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

  // Vendor notices (e.g. auto-cancel) go to the business owner's email.
  const ownerEmailCache = new Map<string, string | undefined>();
  async function ownerEmailFor(ownerId: string | null | undefined) {
    if (!ownerId) return undefined;
    if (ownerEmailCache.has(ownerId)) return ownerEmailCache.get(ownerId);
    const { data } = await supabase
      .from("profiles")
      .select("email")
      .eq("id", ownerId)
      .maybeSingle();
    const email = (data?.email as string | undefined) ?? undefined;
    ownerEmailCache.set(ownerId, email);
    return email;
  }

  // Send a queue row through its channel (+ fallbacks) and record the outcome.
  // deno-lint-ignore no-explicit-any
  async function deliver(
    row: any,
    subject: string,
    message: string,
    recipient: Recipient,
  ) {
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
  }

  let processed = 0;
  for (const row of due ?? []) {
    // Waitlist "a spot opened" notices aren't tied to an appointment.
    if (row.kind === "waitlist_open") {
      const { data: entry } = await supabase
        .from("waitlist_entries")
        .select(
          "id, customer_name, customer_email, service_id, " +
            "services(name), businesses(name, timezone)",
        )
        .eq("id", row.waitlist_entry_id)
        .maybeSingle();
      if (!entry) {
        await supabase.from("reminder_queue").update({
          status: "failed",
          failed_at: new Date().toISOString(),
          error_message: "waitlist entry not found",
        }).eq("id", row.id);
        processed++;
        continue;
      }
      // deno-lint-ignore no-explicit-any
      const w = entry as any;
      const wTz = w.businesses?.timezone ?? "America/Barbados";
      const wSvc = w.services?.name ?? "appointment";
      const wBiz = w.businesses?.name ?? "the business";
      const slotIso = (row.payload?.start_time as string | undefined);
      let whenStr = "";
      if (slotIso) {
        const d = new Date(slotIso);
        const day = new Intl.DateTimeFormat("en-US", {
          timeZone: wTz,
          weekday: "short",
          month: "short",
          day: "numeric",
        }).format(d);
        const t = new Intl.DateTimeFormat("en-US", {
          timeZone: wTz,
          hour: "numeric",
          minute: "2-digit",
        }).format(d);
        whenStr = ` on ${day} at ${t}`;
      }
      const subject = `A spot opened for your ${wSvc} booking`;
      const message =
        `Great news! A spot has just become available for your requested ` +
        `${wSvc} at ${wBiz}${whenStr}. Open Shorivo to book now before ` +
        `someone else does.`;
      await deliver(row, subject, message, {
        userId: row.user_id,
        email: w.customer_email ?? undefined,
      });
      processed++;
      continue;
    }

    // Build the message + recipient from the appointment.
    const { data: appt } = await supabase
      .from("appointments")
      .select(
        "id, customer_name, customer_email, customer_timezone, start_time, " +
          "confirmation_deadline, services(name), " +
          "businesses(name, timezone, owner_id)",
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

    const svc = a.services?.name ?? "appointment";
    const biz = a.businesses?.name ?? "us";
    const kind = (row.kind as string) ?? "appointment";
    const fmtTime = (iso: string) =>
      new Intl.DateTimeFormat("en-US", {
        timeZone: tz,
        hour: "numeric",
        minute: "2-digit",
      }).format(new Date(iso));

    let subject: string;
    let message: string;
    let recipient: Recipient;

    if (kind === "confirmation_reminder") {
      // Nudge the customer to confirm before the window closes.
      const deadlineIso = (row.payload?.deadline as string | undefined) ??
        (a.confirmation_deadline as string | undefined);
      const deadlineStr = deadlineIso ? fmtTime(deadlineIso) : "the deadline";
      subject = `Confirm your ${svc} booking`;
      message =
        `Your ${svc} booking with ${biz} on ${date} at ${time} is awaiting ` +
        `confirmation. Please confirm before ${deadlineStr} to keep it — ` +
        `otherwise it will be automatically cancelled and the time may be ` +
        `offered to another customer. Open Shorivo to confirm.`;
      recipient = { userId: row.user_id, email: a.customer_email ?? undefined };
    } else if (kind === "confirmation_expired_customer") {
      subject = `Your ${svc} booking was cancelled`;
      message =
        `Your ${svc} appointment with ${biz} on ${date} at ${time} wasn't ` +
        `confirmed in time, so it has been cancelled automatically. You're ` +
        `welcome to book another available time in Shorivo.`;
      recipient = { userId: row.user_id, email: a.customer_email ?? undefined };
    } else if (kind === "confirmation_expired_vendor") {
      const ownerEmail = await ownerEmailFor(a.businesses?.owner_id);
      subject = `Auto-cancelled: a customer didn't confirm`;
      message =
        `An appointment was automatically cancelled because the customer did ` +
        `not confirm before the deadline.\n\nCustomer: ` +
        `${a.customer_name ?? "Customer"}\nService: ${svc}\n` +
        `Time: ${date} at ${time}`;
      recipient = { userId: row.user_id, email: ownerEmail };
    } else if (kind === "deposit_submitted_vendor") {
      const ownerEmail = await ownerEmailFor(a.businesses?.owner_id);
      subject = `New deposit received`;
      message =
        `${a.customer_name ?? "A customer"} has submitted proof of payment ` +
        `for:\n\n${svc}\n${date} at ${time}\n\nReview it in Shorivo to ` +
        `confirm the booking.`;
      recipient = { userId: row.user_id, email: ownerEmail };
    } else if (kind === "deposit_approved_customer") {
      subject = `Your ${svc} booking is confirmed`;
      message =
        `Your deposit has been verified and your appointment with ${biz} on ` +
        `${date} at ${time} is now confirmed. See you then!`;
      recipient = { userId: row.user_id, email: a.customer_email ?? undefined };
    } else if (kind === "deposit_rejected_customer") {
      subject = `Your deposit couldn't be verified`;
      message =
        `Your deposit for ${svc} with ${biz} couldn't be verified.\n\n` +
        `Reason: ${(row.payload?.reason as string | undefined) ?? "Not specified"}` +
        `\n\nPlease open Shorivo and upload a new proof of payment to keep ` +
        `your booking.`;
      recipient = { userId: row.user_id, email: a.customer_email ?? undefined };
    } else if (kind === "deposit_expired_customer") {
      subject = `Your ${svc} booking was cancelled`;
      message =
        `Your ${svc} appointment with ${biz} on ${date} at ${time} was ` +
        `cancelled because the deposit wasn't submitted in time. You're ` +
        `welcome to book another available time in Shorivo.`;
      recipient = { userId: row.user_id, email: a.customer_email ?? undefined };
    } else if (kind === "review_request") {
      subject = `How was your appointment with ${biz}?`;
      message =
        `How was your ${svc} with ${biz} on ${date}? Share your experience to ` +
        `help other customers and support quality service on Shorivo. Open the ` +
        `app to leave a review.`;
      recipient = { userId: row.user_id, email: a.customer_email ?? undefined };
    } else if (kind === "review_new") {
      const ownerEmail = await ownerEmailFor(a.businesses?.owner_id);
      const stars = Number(row.payload?.rating ?? 0);
      subject = `You received a new review`;
      message =
        `${a.customer_name ?? "A customer"} left a ${stars}-star review for ` +
        `their ${svc} on ${date}. Open Shorivo to read it and reply.`;
      recipient = { userId: row.user_id, email: ownerEmail };
    } else {
      // Default: pre-appointment reminder (vendor template).
      const settings = await settingsFor(row.business_id);
      const tpl = settings?.reminder_template ?? DEFAULT_TEMPLATE;
      message = renderTemplate(tpl, {
        customer_name: a.customer_name ?? "there",
        service_name: svc,
        business_name: biz,
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
      subject = `Reminder: ${svc} at ${biz}`;
      recipient = { userId: row.user_id, email: a.customer_email ?? undefined };
    }

    await deliver(row, subject, message, recipient);
    processed++;
  }

  // Trial-ending notices (7/3/1 days out), independent of the queue above.
  const trialReminders = await processTrialReminders(supabase);
  // New-message notices -> outbox (Nodemailer dispatcher sends them).
  const messageEmails = await processMessageEmails(supabase);

  return new Response(
    JSON.stringify({ processed, trialReminders, messageEmails }),
    { headers: { "content-type": "application/json" } },
  );
});
