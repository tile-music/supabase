import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js";

export async function createSbServiceClient(options: Object) {
    const supabase = await createClient(
        Deno.env.get("SB_URL") ?? "",
        Deno.env.get("SB_SERVICE_KEY") ?? "",
        options
      );
    return supabase;
}