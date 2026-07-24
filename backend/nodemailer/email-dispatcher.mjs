// ================================================================
// Shorivo -- outbound email dispatcher (Nodemailer).
//
// Single sender for ALL Shorivo email. The Supabase Edge Function
// (process-reminders) can't run Nodemailer, so it ENQUEUES every email
// (booking reminders, trial notices, new-message notices) into
// public.email_outbox. This worker drains that queue via Nodemailer.
//
// It claims rows atomically (claim_outbox_emails uses FOR UPDATE SKIP
// LOCKED), so you can run several workers and never double-send. Failed
// sends are requeued up to 5 attempts, then marked 'failed'.
//
// Install:  npm i @supabase/supabase-js nodemailer
// Env:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY   (service role -- server only!)
//   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, EMAIL_FROM
// Run:      node email-dispatcher.mjs   (or import runOnce() from your cron)
// ================================================================

import { createClient } from '@supabase/supabase-js'
import nodemailer from 'nodemailer'

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false } },
)

const transport = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: Number(process.env.SMTP_PORT ?? 587),
  secure: Number(process.env.SMTP_PORT) === 465,
  auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
})

const FROM = process.env.EMAIL_FROM ?? 'Shorivo <noreply@shorivo.app>'

export async function runOnce(batch = 50) {
  const { data, error } = await supabase.rpc('claim_outbox_emails', {
    p_limit: batch,
  })
  if (error) {
    console.error('claim_outbox_emails failed:', error.message)
    return 0
  }

  let sent = 0
  for (const row of data ?? []) {
    try {
      await transport.sendMail({
        from: FROM,
        to: row.to_email,
        subject: row.subject,
        html: row.html,
      })
      await supabase.rpc('mark_outbox_sent', { p_id: row.id })
      sent++
    } catch (e) {
      const msg = e?.message ?? String(e)
      console.error(`send to ${row.to_email} failed:`, msg)
      // Requeues (up to 5 attempts) or marks 'failed'.
      await supabase.rpc('mark_outbox_failed', { p_id: row.id, p_error: msg })
    }
  }
  return sent
}

// Allow `node email-dispatcher.mjs` for a one-shot run / testing.
if (import.meta.url === `file://${process.argv[1]}`) {
  runOnce().then((n) => {
    console.log(`Sent ${n} email(s).`)
    process.exit(0)
  })
}
