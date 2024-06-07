import { corsHeaders } from "../_shared/cors.ts";
import { createClient } from "supabase";
import * as queryString from "querystring";
import { serve } from "serve";


/**
 * Handles the user data request.
 * 
 * @param _req - The request object.
 * @returns A response object containing the user data or an error message.
 */
async function handleUserDataRequest(_req: Request) {
  console.log(_req);
  let authHeader = _req.headers.get("Authorization")!;
  console.log(authHeader);
  const supabase = await createClient(
    Deno.env.get("SB_URL") ?? "",
    Deno.env.get("SB_ANON_KEY") ?? "",
    { global: { headers: { Authorization: authHeader } } }
  );
  const { data: userData } = await supabase.auth.getUser();
  const user = userData.user;
  const { data: dbData, error } = await supabase
    .from("played_tracks")
    .select("*");
  console.log(user);
  console.log(dbData, error);
  if (dbData.length === 0) {
    return new Response("0", { headers: corsHeaders });
  } else {
    return new Response(JSON.stringify(dbData), { headers: corsHeaders });
  }
}
serve(handleUserDataRequest);
/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/get-user-data' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
