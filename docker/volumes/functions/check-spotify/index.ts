import { corsHeaders } from "../_shared/cors.ts";
import * as queryString from "https://deno.land/x/querystring@v1.0.2/mod.js";
import { serve } from "https://deno.land/std/http/mod.ts";
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
  console.log("check spotify ")
  console.log(_req); // ripe for error handling
  let authHeader = _req.headers.get("Authorization")!;
  console.log(authHeader);
  
  const supabase = await createSbClient(authHeader); 
  /* const { data: userData } = await supabase.auth.getUser();
  const user = userData.user; */
  const { data: dbData, error } = await supabase
    .from("spotify_credentials")
    .select("*")
  /* console.log(user); */
  console.log("sanity check");
  console.log(dbData, error);
  console.log("sanity check");
  if (dbData) {
    return new Response("1", { headers: corsHeaders });
  }else{
    return new Response("0", { headers: corsHeaders });
  }
}
serve(handleCheckSpotify);