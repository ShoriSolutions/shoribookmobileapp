-- ================================================================
-- ShoriBooks — reusable access check for the trial/subscription gate:
-- a business has access with an active paid subscription OR an unexpired
-- trial. The mobile app enforces this in the router; this helper lets
-- vendor write RPCs enforce it server-side too (defense in depth).
-- ================================================================

CREATE OR REPLACE FUNCTION public.has_active_access(p_business_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.businesses
    WHERE id = p_business_id
      AND (
        subscription_status = 'active'
        OR (subscription_status = 'trialing'
            AND trial_ends_at IS NOT NULL
            AND trial_ends_at > now())
      )
  );
$$;
GRANT EXECUTE ON FUNCTION public.has_active_access(UUID) TO authenticated;
