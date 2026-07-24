// ================================================================
// BetterBooking / ShoriBooks — Verify Purchase Edge Function
//
// Server-side validation of an App Store / Google Play in-app
// purchase *before* the subscription entitlement is granted. The
// Flutter client never grants access directly — it forwards the
// store receipt here; this function verifies it with Apple / Google
// and only then activates the plan (with the store's own, trusted
// expiry date).
//
// Runs with the service-role key on the server only — that key and
// the store credentials must NEVER ship in the app.
//
// Deploy: supabase functions deploy verify-purchase
// Secrets (set via the dashboard or `supabase secrets set`):
//   APPLE_SHARED_SECRET        — App Store Connect "app-specific shared secret"
//   GOOGLE_SERVICE_ACCOUNT_JSON — Play service-account key JSON (androidpublisher)
//   ANDROID_PACKAGE_NAME       — e.g. com.shoribooks.app (Google path only)
//   (SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are injected.)
//
// Request:  POST, Authorization: Bearer <caller JWT>
//   {
//     "business_id": "<uuid>",
//     "package_id":  "<uuid>",           // subscription_packages.id
//     "store":       "apple" | "google",
//     "product_id":  "<store product id>",
//     "receipt":     "<base64 receipt>",   // iOS  (serverVerificationData)
//     "purchase_token": "<token>"          // Android (serverVerificationData)
//   }
// Response: 200 { success, status:"active", period_end, verified:true }
//           401 { error:"unauthorized" }
//           403 { error:"forbidden", message }
//           400 { error:"invalid_request", message }
//           402 { error:"receipt_invalid", message }   // failed verification
//           501 { error:"verification_not_configured" } // no store secret set
// ================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2'

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  })
}

// ── Apple: verifyReceipt (prod, falling back to sandbox) ────────────────────
// Returns the latest expiry (ms since epoch) for the given product, or null.
async function verifyApple(
  receipt: string,
  productId: string,
  sharedSecret: string,
): Promise<{ expiresMs: number } | { error: string }> {
  const payload = JSON.stringify({
    'receipt-data': receipt,
    password: sharedSecret,
    'exclude-old-transactions': true,
  })

  async function hit(url: string) {
    const r = await fetch(url, { method: 'POST', body: payload })
    return (await r.json()) as {
      status: number
      latest_receipt_info?: Array<{ product_id: string; expires_date_ms?: string }>
    }
  }

  let res = await hit('https://buy.itunes.apple.com/verifyReceipt')
  // 21007 = a sandbox receipt was sent to production; retry against sandbox.
  if (res.status === 21007) {
    res = await hit('https://sandbox.itunes.apple.com/verifyReceipt')
  }
  if (res.status !== 0) {
    return { error: `apple_status_${res.status}` }
  }

  let latest = 0
  for (const item of res.latest_receipt_info ?? []) {
    if (item.product_id !== productId) continue
    const ms = Number(item.expires_date_ms ?? 0)
    if (ms > latest) latest = ms
  }
  if (latest === 0) return { error: 'no_matching_product' }
  return { expiresMs: latest }
}

// ── Google: service-account JWT → OAuth token → subscription lookup ─────────
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

async function googleAccessToken(sa: { client_email: string; private_key: string }): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'RS256', typ: 'JWT' }
  const claims = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
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
  const assertion = `${unsigned}.${b64url(sig)}`
  const resp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${assertion}`,
  })
  const j = (await resp.json()) as { access_token?: string }
  if (!j.access_token) throw new Error('google_auth_failed')
  return j.access_token
}

async function verifyGoogle(
  purchaseToken: string,
  productId: string,
  packageName: string,
  saJson: string,
): Promise<{ expiresMs: number } | { error: string }> {
  let sa: { client_email: string; private_key: string }
  try {
    sa = JSON.parse(saJson)
  } catch {
    return { error: 'bad_service_account' }
  }
  const token = await googleAccessToken(sa)
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${encodeURIComponent(packageName)}/purchases/subscriptions/` +
    `${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`
  const r = await fetch(url, { headers: { Authorization: `Bearer ${token}` } })
  if (!r.ok) return { error: `google_status_${r.status}` }
  const j = (await r.json()) as { expiryTimeMillis?: string; paymentState?: number }
  const ms = Number(j.expiryTimeMillis ?? 0)
  // paymentState: 0 pending, 1 received, 2 free trial, 3 pending deferred.
  if (j.paymentState === 0 || ms === 0) return { error: 'payment_pending' }
  return { expiresMs: ms }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS })
  if (req.method !== 'POST') {
    return json({ error: 'invalid_request', message: 'Only POST is supported' }, 400)
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return json({ error: 'unauthorized' }, 401)

  let body: {
    business_id?: string
    package_id?: string
    store?: string
    product_id?: string
    receipt?: string
    purchase_token?: string
  }
  try {
    body = await req.json()
  } catch {
    return json({ error: 'invalid_request', message: 'Invalid JSON body' }, 400)
  }

  const businessId = body.business_id?.trim()
  const packageId = body.package_id?.trim()
  const store = body.store?.trim().toLowerCase()
  const productId = body.product_id?.trim()

  if (!businessId) return json({ error: 'invalid_request', message: 'business_id is required' }, 400)
  if (!packageId) return json({ error: 'invalid_request', message: 'package_id is required' }, 400)
  if (store !== 'apple' && store !== 'google') {
    return json({ error: 'invalid_request', message: "store must be 'apple' or 'google'" }, 400)
  }
  if (!productId) return json({ error: 'invalid_request', message: 'product_id is required' }, 400)

  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
  const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
  const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  // ── Step 1: verify the caller & their OWNER/ADMIN role (via their JWT) ──────
  const invokerClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  })
  const { data: userData, error: userError } = await invokerClient.auth.getUser()
  if (userError || !userData?.user) return json({ error: 'unauthorized' }, 401)
  const callerId = userData.user.id

  const { data: membership } = await invokerClient
    .from('business_members')
    .select('role, status')
    .eq('business_id', businessId)
    .eq('user_id', callerId)
    .maybeSingle()

  if (
    !membership ||
    membership.status !== 'ACTIVE' ||
    !['OWNER', 'ADMIN'].includes(membership.role)
  ) {
    return json(
      { error: 'forbidden', message: 'You must be an active OWNER or ADMIN of this business' },
      403,
    )
  }

  // ── Step 2: validate the receipt with the store ────────────────────────────
  let result: { expiresMs: number } | { error: string }
  if (store === 'apple') {
    const secret = Deno.env.get('APPLE_SHARED_SECRET')
    if (!secret) return json({ error: 'verification_not_configured', store }, 501)
    const receipt = body.receipt?.trim()
    if (!receipt) return json({ error: 'invalid_request', message: 'receipt is required' }, 400)
    result = await verifyApple(receipt, productId, secret)
  } else {
    const saJson = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON')
    const pkg = Deno.env.get('ANDROID_PACKAGE_NAME')
    if (!saJson || !pkg) return json({ error: 'verification_not_configured', store }, 501)
    const purchaseToken = body.purchase_token?.trim()
    if (!purchaseToken) {
      return json({ error: 'invalid_request', message: 'purchase_token is required' }, 400)
    }
    result = await verifyGoogle(purchaseToken, productId, pkg, saJson)
  }

  if ('error' in result) {
    return json({ error: 'receipt_invalid', message: result.error }, 402)
  }

  const periodEnd = new Date(result.expiresMs)
  if (periodEnd.getTime() <= Date.now()) {
    return json({ error: 'receipt_invalid', message: 'subscription_expired' }, 402)
  }

  // ── Step 3: grant the entitlement with the *verified* expiry (service role) ─
  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  const token = store === 'apple' ? body.receipt! : body.purchase_token!
  const { error: updateError } = await adminClient
    .from('businesses')
    .update({
      subscription_status: 'active',
      subscription_package_id: packageId,
      subscription_store: store,
      subscription_token: token,
      subscription_period_end: periodEnd.toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq('id', businessId)

  if (updateError) {
    return json({ error: 'invalid_request', message: updateError.message }, 400)
  }

  return json({
    success: true,
    status: 'active',
    period_end: periodEnd.toISOString(),
    verified: true,
  })
})
