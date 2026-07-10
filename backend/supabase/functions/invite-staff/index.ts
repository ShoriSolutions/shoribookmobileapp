// ================================================================
// BetterBooking — Invite Staff Edge Function
//
// Lets an OWNER/ADMIN invite a teammate (ADMIN or STAFF) to their
// business. Runs with the service-role key on the server only —
// this key must NEVER be shipped in the Flutter app.
//
// Deploy: supabase functions deploy invite-staff
// Env required (set via `supabase secrets set`):
//   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
//   (the first two are auto-injected by the platform; only the
//   service role key needs to be set explicitly if not already).
//
// Request:  POST, Authorization: Bearer <caller JWT>
//           { "business_id": "<uuid>", "email": "<string>", "role": "ADMIN"|"STAFF" }
// Response: 200 { success, membership_id, user_id, status }
//           401 { error: "unauthorized" }
//           403 { error: "forbidden", message }
//           400 { error: "invalid_request", message }
//           409 { error: "already_member", message }
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

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS })
  }
  if (req.method !== 'POST') {
    return json({ error: 'invalid_request', message: 'Only POST is supported' }, 400)
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return json({ error: 'unauthorized' }, 401)
  }

  let body: { business_id?: string; email?: string; role?: string }
  try {
    body = await req.json()
  } catch {
    return json({ error: 'invalid_request', message: 'Invalid JSON body' }, 400)
  }

  const businessId = body.business_id?.trim()
  const email = body.email?.trim().toLowerCase()
  const role = body.role?.trim().toUpperCase()

  if (!businessId) return json({ error: 'invalid_request', message: 'business_id is required' }, 400)
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return json({ error: 'invalid_request', message: 'A valid email is required' }, 400)
  }
  if (role !== 'ADMIN' && role !== 'STAFF') {
    // OWNER is deliberately not invitable — ownership transfer is a separate,
    // more sensitive operation and out of scope for this function.
    return json({ error: 'invalid_request', message: 'role must be ADMIN or STAFF' }, 400)
  }

  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
  const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
  const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  // ── Step 1: verify the caller via their own forwarded JWT ──────────────────
  // Server-validated identity (not just decoded), and querying business_members
  // through this invoker client means the existing get_my_business_role-backed
  // RLS policies apply naturally — no auth logic is re-implemented here.
  const invokerClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  })

  const { data: userData, error: userError } = await invokerClient.auth.getUser()
  if (userError || !userData?.user) {
    return json({ error: 'unauthorized' }, 401)
  }
  const callerId = userData.user.id

  const { data: callerMembership } = await invokerClient
    .from('business_members')
    .select('role, status')
    .eq('business_id', businessId)
    .eq('user_id', callerId)
    .maybeSingle()

  if (
    !callerMembership ||
    callerMembership.status !== 'ACTIVE' ||
    !['OWNER', 'ADMIN'].includes(callerMembership.role)
  ) {
    return json(
      { error: 'forbidden', message: 'You must be an active OWNER or ADMIN of this business' },
      403
    )
  }

  // ── Step 2: privileged operations via the service-role admin client ────────
  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  let inviteeUserId: string | null = null

  const redirectTo = Deno.env.get('MOBILE_APP_DEEP_LINK') ?? 'shoribook://auth/callback'

  const { data: inviteResult, error: inviteError } =
    await adminClient.auth.admin.inviteUserByEmail(email, { redirectTo })

  if (inviteError) {
    // "already registered" (or similar) — resolve the existing user via
    // profiles instead of treating this as a hard failure. profiles.id is
    // the auth.users.id, kept in sync by the platform's own user-creation
    // trigger, so this is a safe lookup for an existing account's user id.
    const alreadyRegistered = /already registered|already exists|already been registered/i.test(
      inviteError.message ?? ''
    )
    if (!alreadyRegistered) {
      return json({ error: 'invalid_request', message: inviteError.message }, 400)
    }

    const { data: existingProfile } = await adminClient
      .from('profiles')
      .select('id')
      .eq('email', email)
      .maybeSingle()

    if (!existingProfile) {
      return json(
        { error: 'invalid_request', message: 'This email is registered but could not be resolved' },
        400
      )
    }
    inviteeUserId = existingProfile.id
  } else {
    inviteeUserId = inviteResult.user.id
  }

  if (!inviteeUserId) {
    return json({ error: 'invalid_request', message: 'Could not resolve invitee user id' }, 400)
  }

  // Already a member of this business?
  const { data: existingMembership } = await adminClient
    .from('business_members')
    .select('id, status')
    .eq('business_id', businessId)
    .eq('user_id', inviteeUserId)
    .maybeSingle()

  if (existingMembership) {
    if (existingMembership.status === 'ACTIVE') {
      return json(
        { error: 'already_member', message: 'This person is already an active member of this business' },
        409
      )
    }
    // Existing INVITED row (e.g. resending an invite) — treat as success,
    // no duplicate row needed.
    return json({
      success: true,
      membership_id: existingMembership.id,
      user_id: inviteeUserId,
      status: 'invited',
    })
  }

  const { data: newMembership, error: memberError } = await adminClient
    .from('business_members')
    .insert({ business_id: businessId, user_id: inviteeUserId, role, status: 'INVITED' })
    .select('id')
    .single()

  if (memberError || !newMembership) {
    return json(
      { error: 'invalid_request', message: memberError?.message ?? 'Failed to create membership' },
      400
    )
  }

  return json({
    success: true,
    membership_id: newMembership.id,
    user_id: inviteeUserId,
    status: 'invited',
  })
})
