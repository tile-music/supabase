import { corsHeaders } from "../_shared/cors.ts";
import { serve } from "serve";
import { handleIsrcRequest, MusicRequest, handleEanRequest,handleUpcRequest } from "../_shared/musicbrainz.ts"

/**
 * This function handles a request containing an isrc, ean, or upc and returns the corresponding musicbrainz data...
 * on isrc request, the album name may be passed as well, this is a crude effort to match the entry in musicbrainz...
 * to the album a user actually listened to
 * 
 * @param _req - The request object.
 * @returns A response object containing the musicbrainz data or an error message.  
 */
async function handleMusicbrainzRequest(_req: Request) {
  console.log(_req);
  const reqResolved = await _req.json();
  console.log(reqResolved);
  const body : MusicRequest = reqResolved ;
  let ret;
  if (body.isrcReq) {
    ret = await handleIsrcRequest(body.isrcReq);
  } else if (body.upcReq) {
    console.log("upc");
    //ret = await handleUpcRequest(body.upcReq);
  } else if (body.eanReq) {
    console.log("ean");
    //ret = await handleEanRequest(body.eanReq);
  } else {
    console.log("error" )
  }
  
  console.log(ret);
  return new Response(JSON.stringify(ret), { headers: corsHeaders });
}

serve(handleMusicbrainzRequest);

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/get-musicbrainz-data' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/