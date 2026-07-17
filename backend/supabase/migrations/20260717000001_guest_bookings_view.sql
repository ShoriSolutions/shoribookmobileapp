-- ================================================================
-- ShoriBooks — let a guest view the bookings they made (no account).
-- The app remembers the appointment ids it created on the device; this
-- function returns those appointments ONLY when the caller also supplies
-- the matching phone number. So it takes both an unguessable id AND the
-- phone to return anything — no bulk/enumeration exposure. Returns the
-- same JSON shape the customer bookings UI already parses.
-- ================================================================

CREATE OR REPLACE FUNCTION public.get_guest_appointments(
  p_ids   UUID[],
  p_phone TEXT
)
RETURNS JSONB
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT COALESCE(jsonb_agg(t.row ORDER BY t.st DESC), '[]'::jsonb)
  FROM (
    SELECT
      a.start_time AS st,
      jsonb_build_object(
        'id', a.id,
        'business_id', a.business_id,
        'service_id', a.service_id,
        'staff_profile_id', a.staff_profile_id,
        'customer_id', a.customer_id,
        'start_time', a.start_time,
        'end_time', a.end_time,
        'status', a.status,
        'price', a.price,
        'currency', a.currency,
        'deposit_required', a.deposit_required,
        'deposit_amount', a.deposit_amount,
        'deposit_paid', a.deposit_paid,
        'deposit_status', a.deposit_status,
        'payment_method', a.payment_method,
        'payment_reference', a.payment_reference,
        'deposit_paid_at', a.deposit_paid_at,
        'cancellation_policy_accepted', a.cancellation_policy_accepted,
        'customer_name', a.customer_name,
        'customer_phone', a.customer_phone,
        'customer_email', a.customer_email,
        'notes', a.notes,
        'booking_source', a.booking_source,
        'internal_notes', a.internal_notes,
        'created_at', a.created_at,
        'updated_at', a.updated_at,
        'services', jsonb_build_object('name', s.name),
        'staff_profiles', CASE
          WHEN sp.id IS NULL THEN NULL
          ELSE jsonb_build_object('name', sp.name, 'role', sp.role)
        END,
        'businesses', jsonb_build_object(
          'name', b.name,
          'logo_url', b.logo_url,
          'slug', b.slug,
          'timezone', b.timezone,
          'phone', b.phone,
          'whatsapp_number', b.whatsapp_number
        )
      ) AS row
    FROM public.appointments a
    JOIN public.businesses b ON b.id = a.business_id
    LEFT JOIN public.services s ON s.id = a.service_id
    LEFT JOIN public.staff_profiles sp ON sp.id = a.staff_profile_id
    WHERE btrim(COALESCE(p_phone, '')) <> ''
      AND a.customer_phone = btrim(p_phone)
      AND a.id = ANY(p_ids)
  ) t;
$$;
GRANT EXECUTE ON FUNCTION public.get_guest_appointments(UUID[], TEXT)
  TO anon, authenticated;
