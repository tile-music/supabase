// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
/// <reference types="https://esm.sh/@supabase/functions-js/src/edge-runtime.d.ts" />
import { cryptoRandomString } from "crypto"
import * as queryString from "querystring"
import { serve } from "serve"

const corsHeaders = new Headers ({
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
});

/**
 * 
 * @param _req request from client which must contain the token representing the user's session
 * @returns response that redirects the user to the spotify login page
 * @todo update the scope to be more specific to the user's needs something like, user currently playing
 */
function handleSpotifyLogin(_req: Request) {
  
  const scope = "user-read-private";
  const clientId = Deno.env.get("SP_CID");
  const redirectUrl = Deno.env.get("SP_REDIRECT");
  let authHeader = _req.headers.get("Authorization") 
  console.log("here is that state you need :" , authHeader )
  const spotifyString = "https://accounts.spotify.com/authorize?" +
              queryString.stringify({
                response_type: "code",
                client_id: clientId,
                scope: scope,
                redirect_uri: redirectUrl,
                state: authHeader,
              })
  return new Response( spotifyString, {headers: corsHeaders})
}
serve(handleSpotifyLogin);

