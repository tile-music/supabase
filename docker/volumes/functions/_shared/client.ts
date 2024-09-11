import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js";

export async function createSbClient(authHeader?: string) {
    const supabase = await createClient(
        Deno.env.get("SB_URL") ?? "",
        Deno.env.get("SB_ANON_KEY") ?? "",
        authHeader ? { global: { headers: { Authorization: authHeader } } } : undefined
      );
    return supabase;
}

