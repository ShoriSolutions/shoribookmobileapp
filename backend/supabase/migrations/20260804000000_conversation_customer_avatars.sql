-- ================================================================
-- Shorivo -- expose customer avatars to vendors, WITHOUT leaking PII.
--
-- profiles is locked to own-row reads (20260801000001) so a vendor can't read
-- a customer's profile. Vendors already see the customer's display name
-- (denormalised on the conversation) and now want their photo too. Rather than
-- loosen profiles (which would re-expose email/phone), this SECURITY DEFINER
-- function returns ONLY (user_id, avatar_url) -- never name, email, or phone --
-- and only for customers who already have a conversation with a business the
-- caller is an ACTIVE member of. So a vendor can only see the avatars of their
-- own customers, and nothing sensitive is ever returned.
--
-- Idempotent. ASCII only. Run manually.
-- ================================================================

CREATE OR REPLACE FUNCTION public.conversation_customer_avatars()
RETURNS TABLE(user_id uuid, avatar_url text)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT DISTINCT p.id, p.avatar_url
  FROM public.conversations c
  JOIN public.business_members m
    ON m.business_id = c.business_id
   AND m.user_id = (SELECT auth.uid())
   AND m.status = 'ACTIVE'
  JOIN public.profiles p
    ON p.id = c.customer_user_id
  WHERE c.customer_user_id IS NOT NULL
    AND p.avatar_url IS NOT NULL;
$$;

REVOKE ALL ON FUNCTION public.conversation_customer_avatars() FROM public;
GRANT EXECUTE ON FUNCTION public.conversation_customer_avatars() TO authenticated;

-- ================================================================
-- VERIFY: the function returns ONLY id + avatar_url, and only for the caller's
-- own customers. As a vendor session it should list their customers' photos;
-- as a customer session it returns no rows (they aren't a business member).
-- ================================================================
