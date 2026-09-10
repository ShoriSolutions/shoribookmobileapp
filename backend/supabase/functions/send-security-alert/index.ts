// send-security-alert — emails account owners when their login hit the
// 5-attempt limit ("was this you?"). Drains public.security_alerts (queued
// by record_failed_login), hands each alert to the email queue
// (public.email_outbox, category 'security'), and marks the alert sent.
// dispatch-emails does the actual Resend send, so security alerts count
// toward the same daily Resend budget and go out first (highest priority).
//
// Deploy + schedule (Supabase):
//   supabase functions deploy send-security-alert --no-verify-jwt
//   then a cron (every minute) invokes it, OR call it from a DB webhook on
//   INSERT into security_alerts. No JWT check (like dispatch-emails /
//   process-reminders): it only drains alerts already queued, using its own
//   service-role client, so the cron job needs no stored key.
//
// Secrets (Edge Function env — never in the DB or the app):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (injected by the platform)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const APP_NAME = "Shorivo";

function alertEmail(email: string): { subject: string; body: string } {
  return {
    subject: `${APP_NAME}: unusual sign-in activity on your account`,
    body:
      `<p>We noticed 5 failed sign-in attempts on the ${APP_NAME} account for ` +
      `<b>${email}</b>, so we've temporarily locked it for your protection.</p>` +
      `<p><b>Was this you?</b> If you were just having trouble signing in, you ` +
      `can try again in about 15 minutes.</p>` +
      `<p>If this <b>wasn't you</b>, please reset your password now from the ` +
      `login screen ("Forgot password?").</p>` +
      `<p>— The ${APP_NAME} team</p>`,
  };
}

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const { data: alerts, error } = await supabase
    .from("security_alerts")
    .select("id, email, kind")
    .is("sent_at", null)
    .order("created_at", { ascending: true })
    .limit(50);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  let queued = 0;
  for (const a of alerts ?? []) {
    if (!a.email) continue;
    const { subject, body } = alertEmail(a.email);
    const { error: qErr } = await supabase.from("email_outbox").insert({
      to_email: a.email,
      subject,
      html: body,
      category: "security",
      dedupe_key: `security_alert:${a.id}`,
    });
    // 23505 = already queued by an overlapping run; either way it's handed off.
    if (!qErr || qErr.code === "23505") {
      await supabase
        .from("security_alerts")
        .update({ sent_at: new Date().toISOString() })
        .eq("id", a.id);
      queued++;
    }
  }

  return new Response(JSON.stringify({ processed: alerts?.length ?? 0, queued }), {
    headers: { "Content-Type": "application/json" },
  });
});
