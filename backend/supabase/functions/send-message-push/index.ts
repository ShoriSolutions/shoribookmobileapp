// ================================================================
// Shorivo -- send-message-push Edge Function.
//
// Delivers a push notification to the recipient of a new chat message.
// Intended to be invoked by a Supabase Database Webhook on INSERT into
// public.messages (payload { type, record }), or directly with
// { message_id }.
//
// Flow (service role): message_push_targets(message_id) -> recipient user
// ids + title/body (honours the recipient side's mute flag) -> look up their
// device_push_tokens -> FCM HTTP v1 send. If FCM_SERVICE_ACCOUNT_JSON is not
// set, returns 200 { skipped } so the webhook never error-loops.
//
// Deploy: supabase functions deploy send-message-push --no-verify-jwt
// Secrets:
//   FCM_SERVICE_ACCOUNT_JSON -- Firebase service account key (one line)
//   (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are injected)
// ================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
}

// ── RS256 service-account -> OAuth access token (FCM scope) ────────────────
function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN [^-]+-----/, '')
    .replace(/-----END [^-]+-----/, '')
    .replace(/\s+/g, '')
  const bin = atob(b64)
  const buf = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i)
  return buf.buffer
}
function b64url(data: Uint8Array | string): string {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : data
  let bin = ''
  for (const b of bytes) bin += String.fromCharCode(b)
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}
async function accessToken(sa: { client_email: string; private_key: string }): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'RS256', typ: 'JWT' }
  const claims = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }
  const unsigned = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(claims))}`
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sig = new Uint8Array(
    await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned)),
  )
  const resp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body:
      `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${unsigned}.${b64url(sig)}`,
  })
  const j = (await resp.json()) as { access_token?: string }
  if (!j.access_token) throw new Error('fcm_auth_failed')
  return j.access_token
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return json({ error: 'invalid_request' }, 400)

  let payload: { message_id?: string; record?: { id?: string } }
  try {
    payload = await req.json()
  } catch {
    return json({ error: 'invalid_request' }, 400)
  }
  const messageId = payload.message_id ?? payload.record?.id
  if (!messageId) return json({ error: 'invalid_request', message: 'message id required' }, 400)

  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
  const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const saJson = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')
  if (!saJson) return json({ skipped: 'fcm_not_configured' })

  let sa: { client_email: string; private_key: string; project_id: string }
  try {
    sa = JSON.parse(saJson)
  } catch {
    return json({ error: 'bad_service_account' }, 500)
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  // Recipients (honours mute) + notification copy.
  const { data: targets, error: tErr } = await admin.rpc('message_push_targets', {
    p_message_id: messageId,
  })
  if (tErr) return json({ error: 'targets_failed', message: tErr.message }, 500)
  const rows = (targets ?? []) as Array<{ user_id: string; title: string; body: string }>
  if (rows.length === 0) return json({ sent: 0, reason: 'no_recipients_or_muted' })

  const userIds = [...new Set(rows.map((r) => r.user_id))]
  const { data: tokenRows } = await admin
    .from('device_push_tokens')
    .select('token, user_id')
    .in('user_id', userIds)
  const tokens = (tokenRows ?? []) as Array<{ token: string; user_id: string }>
  if (tokens.length === 0) return json({ sent: 0, reason: 'no_tokens' })

  const title = rows[0].title
  const body = rows[0].body
  const token = await accessToken(sa)
  const endpoint = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`

  let sent = 0
  for (const t of tokens) {
    const r = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: t.token,
          notification: { title, body },
          data: { type: 'message', message_id: messageId },
        },
      }),
    })
    if (r.ok) {
      sent++
    } else if (r.status === 404 || r.status === 400) {
      // Stale/invalid token -> prune it.
      await admin.from('device_push_tokens').delete().eq('token', t.token)
    }
  }

  return json({ sent, recipients: userIds.length })
})
