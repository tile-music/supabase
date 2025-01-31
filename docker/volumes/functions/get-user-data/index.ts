import { corsHeaders } from "../_shared/cors.ts";
import { createSbClient } from "../_shared/client.ts";
import { constructQuery, processPlayedTracksData } from "../_shared/query.ts";

/**
 * Handles the user data request.
 * 
 * @param _req - The request object.
 * @returns A response object containing the user's played tracks' or null if empty.
 */
async function handleUserDataRequest(_req: Request) {
  // create authenticated supabase client scoped to the "prod" schema
  const authHeader = _req.headers.get("Authorization")!;
  const supabase = await createSbClient(authHeader, "prod");
  
  // get user data, since we need it to filter played tracks to the specific user
  const { data: userData } = await supabase.auth.getUser();
  if (!userData.user) throw 'Unable to fetch user.';

  // fetch the track and album information for the current user's played tracks
  const { data: dbData, error } = await constructQuery(supabase, userData.user.id)
  if (error) throw error;

  // process songs into SongInfo and AlbumInfo types
  const songs = processPlayedTracksData(dbData);

  // send the list of songs as a response, or null if there are no songs
  if (songs.length === 0) {
    return new Response(JSON.stringify(null), { headers: corsHeaders });
  } else {
    return new Response(JSON.stringify(songs), { headers: corsHeaders });
  }
}
Deno.serve(handleUserDataRequest);