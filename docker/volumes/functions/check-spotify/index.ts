import { corsHeaders } from "../_shared/cors.ts";
import { createSbClient } from "../_shared/client.ts";

/**
 * 
 * @param _req request from client which must contain the token representing the user's session
 * 
 *  the token for the users session is stored in the Authorization header
 * 
 * @returns response that has a value of either 1 or 0, 1 means the user has spotify credentials...
 * stored and 0 means the user does not have spotify credentials stored
 */
async function handleCheckSpotify(_req: Request) {
  // fetch authorization headers
  const authHeader = _req.headers.get("Authorization")!;

  // create an authenticated supabase client and fetch userid
  const supabase = await createSbClient(authHeader);
  const { data: userData } = await supabase.auth.getUser();
  if (!userData.user) throw 'Unable to fetch user.';
  console.log("userdata", userData.user["id"]);
  const userId = userData.user["id"];
  // check if the user has linked spotify credentials
  const { data: dbData, error } = await supabase
    .from("spotify_credentials")
    .select("*")
    .eq("id", userId);
  console.log("test")
  
  console.log(dbData, "is array", Array.isArray(dbData));
  
  if (dbData.length >0) {
    return new Response("spotify logged in", { headers: corsHeaders });
  }else{
    return new Response("spotify login not found", { headers: corsHeaders });
  }
}
Deno.serve(handleCheckSpotify);