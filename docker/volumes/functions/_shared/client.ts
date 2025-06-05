import { createClient, type SupabaseClientOptions } from "https://esm.sh/@supabase/supabase-js";

/**
 * Creates a Supabase client with specified authorization headers and schema.
 * @param authHeader (optional) An authorization header, typically in the form "Bearer [token]".
 * @param schema (optional) The schema to query, defaults to "public".
 * @returns The Supabase client.
 */
export async function createSbClient(authHeader?: string, schema?: string) {
  // set optional supabase client options, including authorization
  // headers and specified schema (defaults to 'public')
  const global = (authHeader) ? { headers: { Authorization: authHeader } } : undefined;
  const db = (schema) ? { schema } : undefined;
  const options: SupabaseClientOptions<string> = { global, db};
    const supabase = await createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_ANON_KEY") ?? "",
        options
      );
    return supabase;
}

