-- Allow authenticated users to raise their API daily limit after upgrading.
GRANT EXECUTE ON FUNCTION public.set_premium_limit(uuid) TO authenticated;
