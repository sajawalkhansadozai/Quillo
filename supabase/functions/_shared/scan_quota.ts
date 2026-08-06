import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

const FREE_MONTHLY_LIMIT = 2;

export async function isPremiumUser(
  supabase: SupabaseClient,
  userId: string,
): Promise<boolean> {
  const { data } = await supabase
    .from('users')
    .select('subscription_status')
    .eq('id', userId)
    .maybeSingle();
  return data?.subscription_status === 'premium';
}

export async function consumeMonthlyScan(
  supabase: SupabaseClient,
  userId: string,
): Promise<{ allowed: boolean; message?: string }> {
  if (await isPremiumUser(supabase, userId)) {
    return { allowed: true };
  }

  const { data, error } = await supabase.rpc('consume_monthly_scan', {
    p_user_id: userId,
  });

  if (error) {
    console.error('consume_monthly_scan error:', error.message);
    return { allowed: false, message: 'Could not verify scan quota.' };
  }

  if (data === true) return { allowed: true };

  return {
    allowed: false,
    message: `You've used all ${FREE_MONTHLY_LIMIT} free scans this month. Upgrade to Premium for unlimited scanning.`,
  };
}
