-- ================================================================
-- Shorivo -- close the free-trial bypass (pay-to-enter paywall).
--
-- The professional side is gated by businesses.hasActiveAccess: a new business
-- starts at subscription_status = 'none' and the app routes it to the
-- subscription-required screen. Access is meant to come ONLY through a real
-- App Store / Play purchase (the Apple/Google free-trial intro offer collects
-- the card), verified server-side by the verify-purchase Edge Function, which
-- sets subscription_status = 'active'.
--
-- The app no longer calls start_trial() anywhere, but the RPC was still granted
-- to `authenticated`, so a user could call it directly (via the API) to grant
-- themselves a free 'trialing' status and skip payment. Revoke that grant so
-- there is no cardless way onto the pro side. The function is kept (service_role
-- bypasses grants) so an admin can still comp a trial deliberately.
--
-- Idempotent. Run manually.
-- ================================================================

REVOKE EXECUTE ON FUNCTION public.start_trial(UUID) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.start_trial(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION public.start_trial(UUID) FROM public;
