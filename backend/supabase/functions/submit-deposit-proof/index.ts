// ============================================================================
// submit-deposit-proof — Supabase Edge Function
//
// Guest proof-of-deposit upload. Guests have no auth session, so they can't
// write to the private deposit-proofs bucket directly; this function validates
// the appointment id + phone (same trust model as the other guest RPCs), then
// uploads the image and records the submission via the service role.
//
// Authed customers DON'T use this — they upload to storage directly (RLS) and
// call the submit_deposit RPC.
//
// Deploy:  supabase functions deploy submit-deposit-proof --no-verify-jwt
// Body:    { appointment_id, phone, image_base64, content_type, reference?, notes? }
// ============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  });
}

function extFor(contentType: string): string {
  if (contentType === "image/png") return "png";
  if (contentType === "image/webp") return "webp";
  return "jpg";
}

function decodeBase64(b64: string): Uint8Array {
  const clean = b64.includes(",") ? b64.split(",")[1] : b64; // strip data: prefix
  const bin = atob(clean);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid body" }, 400);
  }

  const appointmentId = String(body.appointment_id ?? "");
  const phone = String(body.phone ?? "").trim();
  const imageB64 = String(body.image_base64 ?? "");
  const contentType = String(body.content_type ?? "image/jpeg");
  const reference = body.reference ? String(body.reference).trim() : null;
  const notes = body.notes ? String(body.notes).trim() : null;

  if (!appointmentId || !phone || !imageB64) {
    return json({ error: "appointment_id, phone and image_base64 required" }, 400);
  }

  // Validate the booking: exists, awaiting deposit, and the phone matches.
  const { data: appt } = await admin
    .from("appointments")
    .select("id, business_id, status, deposit_amount, currency, customer_phone")
    .eq("id", appointmentId)
    .maybeSingle();
  if (!appt) return json({ error: "appointment not found" }, 404);
  // deno-lint-ignore no-explicit-any
  const a = appt as any;
  if ((a.customer_phone ?? "").trim() !== phone) {
    return json({ error: "forbidden" }, 403);
  }
  if (a.status !== "pending_deposit") {
    return json({ status: "not_pending", appointment_status: a.status });
  }

  // Upload the proof.
  let bytes: Uint8Array;
  try {
    bytes = decodeBase64(imageB64);
  } catch {
    return json({ error: "invalid image" }, 400);
  }
  const path = `${a.business_id}/${appointmentId}/${crypto.randomUUID()}.${
    extFor(contentType)
  }`;
  const up = await admin.storage
    .from("deposit-proofs")
    .upload(path, bytes, { contentType, upsert: false });
  if (up.error) return json({ error: "upload failed" }, 500);

  // Supersede any earlier open submissions, then record the new one.
  await admin.from("deposit_submissions")
    .update({ status: "superseded" })
    .eq("appointment_id", appointmentId)
    .in("status", ["submitted", "rejected"]);

  const { data: sub, error: subErr } = await admin
    .from("deposit_submissions")
    .insert({
      appointment_id: appointmentId,
      business_id: a.business_id,
      user_id: null,
      amount: a.deposit_amount,
      currency: a.currency,
      proof_path: path,
      reference_number: reference,
      customer_notes: notes,
      status: "submitted",
    })
    .select("id")
    .single();
  if (subErr) return json({ error: "could not record submission" }, 500);
  // deno-lint-ignore no-explicit-any
  const submissionId = (sub as any).id;

  await admin.from("deposit_audit_log").insert({
    business_id: a.business_id,
    appointment_id: appointmentId,
    submission_id: submissionId,
    action: "submitted",
  });

  // Notify the vendor (drained by process-reminders / the email dispatcher).
  const { data: biz } = await admin
    .from("businesses").select("owner_id").eq("id", a.business_id).maybeSingle();
  await admin.from("reminder_queue").insert({
    booking_id: appointmentId,
    business_id: a.business_id,
    // deno-lint-ignore no-explicit-any
    user_id: (biz as any)?.owner_id ?? null,
    channel: "email",
    scheduled_for: new Date().toISOString(),
    kind: "deposit_submitted_vendor",
  });

  return json({ status: "submitted", submission_id: submissionId });
});
