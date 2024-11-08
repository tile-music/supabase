// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
/// <reference types="https://esm.sh/@supabase/functions-js/src/edge-runtime.d.ts" />

import { decode as base64Decode, encode as base64Encode } from "https://deno.land/std@0.166.0/encoding/base64.ts";
import * as queryString from "https://deno.land/x/querystring@v1.0.2/mod.js";
import { createClient } from "https://esm.sh/@supabase/supabase-js"
import { corsHeaders } from "../_shared/cors.ts";
import { environment } from "../_shared/environment.ts";



console.log("Hello from Functions!");

/**
 * 
 * @param _req request from spotify that contains the code needed to request...
 * the user's credentials the request also contains the state which in this case..
 * is the user's token
 * @returns redirects the user to the account page
 * @todo add a way to confirm the credentials were grabbed successfully
 */
async function handleSpotifyCallbackRequest(_req: Request) {
  const params = queryString.parse(new URL(_req.url).search)
  
  const token = params.state.toString().replace("+", " ")
  console.log("token", token)
  /* this needs to get shared amongst the various edge functions some how but i have no idea how to make it work */
  if (params.state === null) {
    return new Response (
      "/#" +
      queryString.stringify({
        error: "state_mismatch",
      }),
      {headers: corsHeaders}
    );
  } else {

    console.log("params",params, token)
    
    await handleSpotifyCredentials(token,params)
    const headers = new Headers({location: environment.FRONTEND_URL,
                                  ...corsHeaders
     })
    console.log(headers)
    return new Response(null, {
      status: 302,
      headers,
    })
  }
}

/**
 * 
 * @param params represents the parameters that hold the user's token, which is passed
 * to spotify to maintain the user's session
 * @todo add a way to confirm the credentials were grabbed successfully
 * @returns 
 */
async function getSpotifyCredentials(params) : Promise<JSON>{
  const clientSecret = environment.SP_SECRET
  const clientId = environment.SP_CID
  const redirectUrl = environment.SP_REDIRECT
  const encodedCredentials = base64Encode(clientId + ":" + clientSecret)
  console.log(encodedCredentials)
  const response =  fetch("https://accounts.spotify.com/api/token",{
    method: "POST",
    body: new URLSearchParams({
      code: params.code,
      redirect_uri: redirectUrl,
      grant_type: 'authorization_code',
    }),
    headers: {
      "content-type": "application/x-www-form-urlencoded",
      Authorization:
      "Basic " +
      encodedCredentials,
      ...corsHeaders,
    },
    
  })
  return (await response).json();

}
/**
 * 
 * @param creds represents the spotify credentials to be stroerd
 * @param token represents the token that is being used to authenticate the user
 * @sideeffect grabs the user's spotify profile photo
 * @returns true if the credentials are stored successfully and false if they are not
 */
async function storeSpotifyCredentials(creds: JSON, token){
  if (token === null){
    console.log("token is null")
    return false;
  } 
  console.log("token", token )
  const supabase = await createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: token} } }
  )
  
  const { data: { user } } = await supabase.auth.getUser()

  
  console.log('user', user.id);
  const { data: credsData, error: grabError } = await supabase.from('spotify_credentials').select('*')
  
  if (grabError) {
    console.log('grab error', grabError)
    return false;
  }else{
    console.log('data', await credsData)
  }
  addSpotifyCredentialsToDataAcquisition(user.id, creds.refresh_token)
  const deleteResponse = await supabase.from('spotify_credentials').delete().eq('id', await user.id)  
  if(deleteResponse){
    console.log('delete error', deleteResponse)
  }
  const { error : insertError } = await supabase.from('spotify_credentials').insert({
    id: await user.id,
    refresh_token: creds.refresh_token,
  })

  if(insertError){
    console.log('error', insertError)
    return false;
  }
  return true;
}
async function addSpotifyCredentialsToDataAcquisition(userId:string, token:any){
  await fetch("http://data-acquisition:3001/add-job", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders
    },
    body: JSON.stringify({
      userId: userId,
      refreshToken: token,
      type: "spotify"
    })
  })
  

}
/**
 * 
 * @param token represents the token that is being used to authenticate the user
 * @param params represents the parameters that hold the user's token, which is passed
 * to spotify to maintain the user's session
 * @returns true if the credentials are stored successfully and false if they are not
 */

async function handleSpotifyCredentials(token, params){
  const creds = await getSpotifyCredentials(params)
  console.log(creds)
  
  return await storeSpotifyCredentials(creds, token)

}

Deno.serve(handleSpotifyCallbackRequest);