// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
/// <reference types="https://esm.sh/@supabase/functions-js/src/edge-runtime.d.ts" />
import { cryptoRandomString } from "https://deno.land/x/crypto_random_string@1.0.0/mod.ts";
import * as queryString from "https://deno.land/x/querystring@v1.0.2/mod.js";
import { serve } from "https://deno.land/std/http/mod.ts";

console.log("Hello from Functions!");

function handler(_req: Request) {
  const corsHeaders = new Headers ({
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  });
  const scope = "user-read-private";
  const client_id = Deno.env.get("SP_CID");
  const redirect_uri = Deno.env.get("SP_REDIRECT");
  const state = cryptoRandomString({ length: 16 });
  const spotifyString = "https://accounts.spotify.com/authorize?" +
  queryString.stringify({
    response_type: "code",
    client_id: client_id,
    scope: scope,
    redirect_uri: redirect_uri,
    state: state,
  })
  return new Response( spotifyString, {headers: corsHeaders}
    
  );
}
serve(handler);
/* var client_id = 'CLIENT_ID';
var redirect_uri = 'http://localhost:8888/callback';

var app = express();

app.get('/login', function(req, res) {

  var scope = 'user-read-private user-read-email';

  res.redirect('https://accounts.spotify.com/authorize?' +
    querystring.stringify({
      response_type: 'code',
      client_id: client_id,
      scope: scope,
      redirect_uri: redirect_uri,
      state: state
    }));
}); */
/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/spotify-login' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
