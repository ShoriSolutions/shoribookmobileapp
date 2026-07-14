-- ================================================================
-- BetterBooking — Smart Appointment Reminder System (MVP)
-- Additive. Extends the booking workflow; does not refactor it.
--
-- Scheduling is entirely server-side: appointment triggers enqueue/cancel
-- rows in reminder_queue; a separate scheduled job (Edge Function
-- `process-reminders`, invoked by cron) reads due rows and dispatches via
-- the provider abstraction. Flutter only reads/writes settings, prefs,
-- templates, and history — it never schedules or sends.
--
-- Provider-agnostic: channels are just strings; adding a provider needs no
-- change to booking logic. WhatsApp is OFFICIAL Business Platform only
-- (Meta Cloud API / Twilio / 360dialog); credentials live server-side, in
-- the Edge Function environment — never in this database or in Flutter.
-- ================================================================

-- ── 1. Vendor notification settings (one row per business) ──────────────────
CREATE TABLE IF NOT EXISTS public.notification_settings (
  business_id       UUID PRIMARY KEY REFERENCES public.businesses(id) ON DELETE CASCADE,
  push_enabled      BOOLEAN NOT NULL DEFAULT true,
  email_enabled     BOOLEAN NOT NULL DEFAULT true,
  whatsapp_enabled  BOOLEAN NOT NULL DEFAULT false,
  sms_enabled       BOOLEAN NOT NULL DEFAULT false,
  -- Minutes-before-appointment for each reminder (e.g. 1440 = 24h, 120 = 2h).
  reminder_offsets  INT[]   NOT NULL DEFAULT ARRAY[1440, 120],
  reminder_template TEXT    NOT NULL DEFAULT
    'Hi {{customer_name}}, this is a reminder of your {{service_name}} '
    'appointment with {{business_name}} on {{date}} at {{time}}. '
    'Ref: {{booking_reference}}',
  -- WhatsApp connection status is managed server-side when official
  -- credentials are configured; Flutter reads it but must not set it.
  whatsapp_provider  TEXT,   -- 'meta_cloud' | 'twilio' | '360dialog' | null
  whatsapp_connected BOOLEAN NOT NULL DEFAULT false,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.notification_settings ENABLE ROW LEVEL SECURITY;

-- ── 2. Customer notification preferences (one row per user) ─────────────────
CREATE TABLE IF NOT EXISTS public.customer_notification_preferences (
  user_id             UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  push_enabled        BOOLEAN NOT NULL DEFAULT true,
  whatsapp_enabled    BOOLEAN NOT NULL DEFAULT true,
  email_enabled       BOOLEAN NOT NULL DEFAULT true,
  promotional_opt_out BOOLEAN NOT NULL DEFAULT false,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.customer_notification_preferences ENABLE ROW LEVEL SECURITY;

-- ── 3. Reminder queue (also the delivery history) ───────────────────────────
CREATE TABLE IF NOT EXISTS public.reminder_queue (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id    UUID NOT NULL REFERENCES public.appointments(id) ON DELETE CASCADE,
  business_id   UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  channel       TEXT NOT NULL,  -- 'push' | 'email' | 'whatsapp' | 'sms'
  scheduled_for TIMESTAMPTZ NOT NULL,
  status        TEXT NOT NULL DEFAULT 'pending', -- pending|sent|delivered|read|failed|cancelled
  sent_at       TIMESTAMPTZ,
  failed_at     TIMESTAMPTZ,
  retry_count   INT NOT NULL DEFAULT 0,
  error_message TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- The cron poller reads due pending rows by (status, scheduled_for).
CREATE INDEX IF NOT EXISTS idx_reminder_queue_due
  ON public.reminder_queue(status, scheduled_for);
CREATE INDEX IF NOT EXISTS idx_reminder_queue_business
  ON public.reminder_queue(business_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reminder_queue_booking
  ON public.reminder_queue(booking_id);
ALTER TABLE public.reminder_queue ENABLE ROW LEVEL SECURITY;

-- ── 4. RLS ──────────────────────────────────────────────────────────────────
-- Vendor settings: OWNER/ADMIN of the business manage; everyone else none.
DROP POLICY IF EXISTS "notif_settings_manage" ON public.notification_settings;
CREATE POLICY "notif_settings_manage" ON public.notification_settings
  FOR ALL TO authenticated
  USING (public.get_my_business_role(business_id) IN ('OWNER', 'ADMIN') OR public.is_admin())
  WITH CHECK (public.get_my_business_role(business_id) IN ('OWNER', 'ADMIN') OR public.is_admin());
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notification_settings TO authenticated;

-- Customer preferences: each user manages their own row.
DROP POLICY IF EXISTS "notif_prefs_self" ON public.customer_notification_preferences;
CREATE POLICY "notif_prefs_self" ON public.customer_notification_preferences
  FOR ALL TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));
GRANT SELECT, INSERT, UPDATE ON public.customer_notification_preferences TO authenticated;

-- Reminder history: business OWNER/ADMIN see their queue; the customer sees
-- their own; admins see all. No client writes — only server functions/cron.
DROP POLICY IF EXISTS "reminder_queue_read" ON public.reminder_queue;
CREATE POLICY "reminder_queue_read" ON public.reminder_queue
  FOR SELECT TO authenticated
  USING (
    public.get_my_business_role(business_id) IN ('OWNER', 'ADMIN')
    OR user_id = (SELECT auth.uid())
    OR public.is_admin()
  );
GRANT SELECT ON public.reminder_queue TO authenticated;

-- ── 5. Server-side scheduling ───────────────────────────────────────────────
-- Enqueue all reminder rows for a booking, honouring vendor settings and the
-- customer's channel preferences, skipping past times and duplicates.
CREATE OR REPLACE FUNCTION public.generate_reminders(p_booking_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_appt        RECORD;
  v_push        BOOLEAN; v_email BOOLEAN; v_wa BOOLEAN; v_sms BOOLEAN;
  v_wa_conn     BOOLEAN;
  v_offsets     INT[];
  v_uid         UUID;
  v_cust_push   BOOLEAN := true;
  v_cust_wa     BOOLEAN := true;
  v_cust_email  BOOLEAN := true;
  v_channels    TEXT[] := ARRAY[]::TEXT[];
  v_offset      INT;
  v_ch          TEXT;
  v_when        TIMESTAMPTZ;
BEGIN
  SELECT id, business_id, customer_id, start_time, status
    INTO v_appt FROM public.appointments WHERE id = p_booking_id;
  IF NOT FOUND THEN RETURN; END IF;
  -- Smart logic: never schedule for terminal or past appointments.
  IF v_appt.status IN ('cancelled', 'completed', 'no_show') THEN RETURN; END IF;
  IF v_appt.start_time <= now() THEN RETURN; END IF;

  -- Vendor settings (defaults if the business hasn't configured any).
  SELECT push_enabled, email_enabled, whatsapp_enabled, sms_enabled,
         whatsapp_connected, reminder_offsets
    INTO v_push, v_email, v_wa, v_sms, v_wa_conn, v_offsets
    FROM public.notification_settings WHERE business_id = v_appt.business_id;
  IF NOT FOUND THEN
    v_push := true; v_email := true; v_wa := false; v_sms := false;
    v_wa_conn := false; v_offsets := ARRAY[1440, 120];
  END IF;

  -- Customer preferences (only when the booking is linked to an account).
  SELECT user_id INTO v_uid FROM public.customers WHERE id = v_appt.customer_id;
  IF v_uid IS NOT NULL THEN
    SELECT push_enabled, whatsapp_enabled, email_enabled
      INTO v_cust_push, v_cust_wa, v_cust_email
      FROM public.customer_notification_preferences WHERE user_id = v_uid;
    -- If no prefs row, defaults above (all channels allowed) apply.
  END IF;

  -- Effective channels = vendor enabled AND customer opted-in.
  IF v_push  AND (v_uid IS NULL OR v_cust_push)  THEN v_channels := v_channels || 'push';  END IF;
  IF v_email AND (v_uid IS NULL OR v_cust_email) THEN v_channels := v_channels || 'email'; END IF;
  -- WhatsApp only when the vendor has connected an official Business account.
  IF v_wa AND v_wa_conn AND (v_uid IS NULL OR v_cust_wa) THEN v_channels := v_channels || 'whatsapp'; END IF;
  -- SMS: architecture only for the MVP — intentionally not enqueued yet.

  IF array_length(v_channels, 1) IS NULL OR v_offsets IS NULL THEN RETURN; END IF;

  FOREACH v_offset IN ARRAY v_offsets LOOP
    v_when := v_appt.start_time - (v_offset || ' minutes')::interval;
    CONTINUE WHEN v_when <= now();  -- don't schedule reminders in the past
    FOREACH v_ch IN ARRAY v_channels LOOP
      INSERT INTO public.reminder_queue(booking_id, business_id, user_id, channel, scheduled_for)
      SELECT p_booking_id, v_appt.business_id, v_uid, v_ch, v_when
      WHERE NOT EXISTS (           -- no duplicate pending reminders
        SELECT 1 FROM public.reminder_queue
        WHERE booking_id = p_booking_id AND channel = v_ch
          AND scheduled_for = v_when AND status = 'pending'
      );
    END LOOP;
  END LOOP;
END;
$$;

-- Cancel all still-pending reminders for a booking.
CREATE OR REPLACE FUNCTION public.cancel_reminders(p_booking_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE public.reminder_queue
     SET status = 'cancelled'
   WHERE booking_id = p_booking_id AND status = 'pending';
END;
$$;

-- ── 6. Booking triggers: keep reminders in sync with the appointment ────────
CREATE OR REPLACE FUNCTION public.appointments_reminders_sync()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM public.generate_reminders(NEW.id);
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.status IN ('cancelled', 'completed', 'no_show')
       AND NEW.status IS DISTINCT FROM OLD.status THEN
      PERFORM public.cancel_reminders(NEW.id);       -- stop remaining reminders
    ELSIF NEW.start_time IS DISTINCT FROM OLD.start_time THEN
      PERFORM public.cancel_reminders(NEW.id);       -- rescheduled: rebuild
      PERFORM public.generate_reminders(NEW.id);
    ELSIF NEW.status = 'confirmed' AND OLD.status IS DISTINCT FROM 'confirmed' THEN
      PERFORM public.generate_reminders(NEW.id);     -- idempotent (dedup guard)
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_appointments_reminders ON public.appointments;
CREATE TRIGGER trg_appointments_reminders
  AFTER INSERT OR UPDATE ON public.appointments
  FOR EACH ROW EXECUTE FUNCTION public.appointments_reminders_sync();

-- ── 7. Upsert helpers for the app (settings/prefs) ──────────────────────────
-- Vendors save channel/timing/template settings (never whatsapp_connected —
-- that is set server-side once official credentials are configured).
CREATE OR REPLACE FUNCTION public.save_notification_settings(
  p_business_id       UUID,
  p_push              BOOLEAN,
  p_email             BOOLEAN,
  p_whatsapp          BOOLEAN,
  p_sms               BOOLEAN,
  p_offsets           INT[],
  p_template          TEXT
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF public.get_my_business_role(p_business_id) NOT IN ('OWNER', 'ADMIN') THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.notification_settings(
    business_id, push_enabled, email_enabled, whatsapp_enabled, sms_enabled,
    reminder_offsets, reminder_template, updated_at)
  VALUES (p_business_id, p_push, p_email, p_whatsapp, p_sms,
          COALESCE(p_offsets, ARRAY[1440, 120]),
          COALESCE(NULLIF(btrim(p_template), ''),
                   (SELECT reminder_template FROM public.notification_settings WHERE business_id = p_business_id)),
          now())
  ON CONFLICT (business_id) DO UPDATE SET
    push_enabled = EXCLUDED.push_enabled,
    email_enabled = EXCLUDED.email_enabled,
    whatsapp_enabled = EXCLUDED.whatsapp_enabled,
    sms_enabled = EXCLUDED.sms_enabled,
    reminder_offsets = EXCLUDED.reminder_offsets,
    reminder_template = COALESCE(EXCLUDED.reminder_template, public.notification_settings.reminder_template),
    updated_at = now();
END;
$$;
GRANT EXECUTE ON FUNCTION public.save_notification_settings(UUID, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, INT[], TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.save_notification_preferences(
  p_push BOOLEAN, p_whatsapp BOOLEAN, p_email BOOLEAN, p_promo_opt_out BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_uid UUID := (SELECT auth.uid());
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  INSERT INTO public.customer_notification_preferences(
    user_id, push_enabled, whatsapp_enabled, email_enabled, promotional_opt_out, updated_at)
  VALUES (v_uid, p_push, p_whatsapp, p_email, p_promo_opt_out, now())
  ON CONFLICT (user_id) DO UPDATE SET
    push_enabled = EXCLUDED.push_enabled,
    whatsapp_enabled = EXCLUDED.whatsapp_enabled,
    email_enabled = EXCLUDED.email_enabled,
    promotional_opt_out = EXCLUDED.promotional_opt_out,
    updated_at = now();
END;
$$;
GRANT EXECUTE ON FUNCTION public.save_notification_preferences(BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN) TO authenticated;

-- FUTURE / extension points:
--  • SMS channel: add to v_channels above + a provider in process-reminders.
--  • Per-channel templates + richer placeholders.
--  • "Immediately after confirmation" reminder (enqueue scheduled_for = now()).
--  • Fallback ordering config + delivery-webhook status updates (delivered/read).
--  • Backfill existing future appointments once a business first saves settings.
