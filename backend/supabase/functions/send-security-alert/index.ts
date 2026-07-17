// send-security-alert — emails account owners when their login hit the
// 5-attempt limit ("was this you?"). Drains public.security_alerts (queued
// by record_failed_login) and marks rows sent.
//
// Deploy + schedule (Supabase):
//   supabase functions deploy send-security-alert
//   then a cron (every minute) invokes it, OR call it from a DB webhook on
//   INSERT into security_alerts.
//
// Secrets (Edge Function env — never in the DB or the app):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//   EMAIL_PROVIDER=resend|sendgrid|ses  + that provider's API key/from-addr
//
// Until a provider is implemented below, alerts queue but aren't emailed.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FROM = Deno.env.get("SECURITY_FROM_EMAIL") ?? "security@shorisolutions.com";
const APP_NAME = "ShoriBooks";

interface EmailResult {
  ok: boolean;
  error?: string;
}

// TODO: implement against your chosen provider (env-configured).
async function sendEmail(to: string, subject: string, body: string): Promise<EmailResult> {
  const provider = Deno.env.get("EMAIL_PROVIDER");
  if (!provider) return { ok: false, error: "email provider not configured" };
  // e.g. Resend:
  //   const r = await fetch("https://api.resend.com/emails", {
  //     method: "POST",
  //     headers: { Authorization: `Bearer ${Deno.env.get("RESEND_API_KEY")}`,
  //                "Content-Type": "application/json" },
  //     body: JSON.stringify({ from: FROM, to, subject, html: body }),
  //   });
  //   return { ok: r.ok, error: r.ok ? undefined : await r.text() };
  return { ok: false, error: `provider ${provider} not implemented` };
}

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

  let sent = 0;
  for (const a of alerts ?? []) {
    const { subject, body } = alertEmail(a.email);
    const res = await sendEmail(a.email, subject, body);
    if (res.ok) {
      await supabase
        .from("security_alerts")
        .update({ sent_at: new Date().toISOString() })
        .eq("id", a.id);
      sent++;
    }
  }

  return new Response(JSON.stringify({ processed: alerts?.length ?? 0, sent }), {
    headers: { "Content-Type": "application/json" },
  });
});
