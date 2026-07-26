-- ================================================================
-- Shorivo -- expose the (non-sensitive) booking-policy flags to guests so the
-- marketplace/booking wizard can show the right UI (e.g. a "Join waitlist"
-- option) before a booking exists.
--
-- The anon role has column-level SELECT on businesses (see
-- 20260721000014_marketplace_access_final). The confirmation/waitlist columns
-- added in Phase 1/2 weren't in that grant, so guest reads that include them
-- would 401. Grant just these three flags -- they are not sensitive.
--
-- Additive + idempotent. ASCII only. Run manually.
-- ================================================================

GRANT SELECT (require_confirmation, confirmation_window_minutes, waitlist_enabled)
  ON public.businesses TO anon;
