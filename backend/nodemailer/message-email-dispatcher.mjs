// ================================================================
// Shorivo -- new-message email dispatcher (Nodemailer).
//
// Reference consumer for the messaging email notifications. Run this on a
// schedule in your Node backend (e.g. every minute via cron / a worker). It
// asks Postgres who has an unread chat message worth emailing, then sends via
// your existing Nodemailer transport.
//
// The heavy lifting lives in the DB RPC `claim_message_email_targets`, which:
//   - waits out a short grace period so active chats don't trigger email,
//   - honours the recipient side's mute flag,
//   - de-dupes per (conversation, recipient) on a cooldown,
//   - CLAIMS the rows atomically, so running this more than once (or
//     alongside another worker) never double-sends.
// => keep exactly ONE consumer of this RPC.
//
// Install:  npm i @supabase/supabase-js nodemailer
// Env:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY   (service role -- server only!)
//   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, EMAIL_FROM
// Run:      node message-email-dispatcher.mjs   (or import runOnce() from your cron)
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

function escapeHtml(s = '') {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}

export async function runOnce() {
  const { data, error } = await supabase.rpc('claim_message_email_targets', {
    p_grace_minutes: 3,
    p_cooldown_minutes: 60,
  })
  if (error) {
    console.error('claim_message_email_targets failed:', error.message)
    return 0
  }

  let sent = 0
  for (const t of data ?? []) {
    const first = (t.recipient_name || 'there').split(' ')[0]
    const extra = t.unread > 1 ? ` (${t.unread} new messages)` : ''
    const preview = t.preview ? `: "${escapeHtml(t.preview)}"` : ''
    const subject = `New message from ${t.other_name}`
    const html =
      `<p>Hi ${escapeHtml(first)}, you have a new message from ` +
      `${escapeHtml(t.other_name)} on Shorivo${extra}${preview}. ` +
      `Open the app to reply.</p>`
    try {
      await transport.sendMail({ from: FROM, to: t.recipient_email, subject, html })
      sent++
    } catch (e) {
      // The row is already claimed for the cooldown window; it will re-appear
      // after the cooldown if still unread. Log and continue.
      console.error(`send to ${t.recipient_email} failed:`, e?.message ?? e)
    }
  }
  return sent
}

// Allow `node message-email-dispatcher.mjs` for a one-shot run / testing.
if (import.meta.url === `file://${process.argv[1]}`) {
  runOnce().then((n) => {
    console.log(`Sent ${n} message email(s).`)
    process.exit(0)
  })
}
