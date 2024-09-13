import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js";

export async function createSbClient(authHeader?: string) {
  console.log(Deno.env.toObject());
    const supabase = await createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_ANON_KEY") ?? "",
        authHeader ? { global: { headers: { Authorization: authHeader } } } : undefined
      );
    return supabase;
}

