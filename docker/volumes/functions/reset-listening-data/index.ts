import { corsHeaders } from "../_shared/cors.ts";
import { createSbClient } from "../_shared/client.ts";

/**
 * Handles the user data request.
 * 
 * @param _req - The request object.
 * @returns Either true or false, depending on if the song removal was successful
 */
async function handleResetListeningDataRequest(_req: Request) {
  // create authenticated supabase client scoped to the "prod" schema
  const authHeader = _req.headers.get("Authorization")!;
  const supabase = await createSbClient(authHeader, "prod");
  
  // get user data, since we need it to remove only tracks from this user
  const { data: userData } = await supabase.auth.getUser();
  if (!userData.user) {
    console.error(new Error("not authenticated"));
    return new Response(JSON.stringify({ not_authenticated: true }), { headers: corsHeaders });
  }

  // remove all played tracks by this user's user id
  const { data, error } = await supabase
    .from("played_tracks")
    .delete()
    .eq("user_id", userData.user.id)
    .select("play_id");

  // handle errors
  if (error) {
    console.error(error);
    return new Response(JSON.stringify({ server_error: true }), { headers: corsHeaders });
  }

  // make sure data was removed
  if (!data.length || data.length == 0)
    return new Response(JSON.stringify({ no_action: true }), { headers: corsHeaders });

  return new Response(JSON.stringify({ success: true }), { headers: corsHeaders });
}
Deno.serve(handleResetListeningDataRequest);