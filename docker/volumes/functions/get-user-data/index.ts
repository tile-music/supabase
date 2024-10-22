import { corsHeaders } from "../_shared/cors.ts";
import { createSbClient } from "../_shared/client.ts";

type song = {
  album_art_path: string
  title: string
  artists: string[]
  album: string
}

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
  const { data: dbData, error } = await supabase
    .from("played_tracks")
    .select(`
      listened_at,
      tracks ( track_name, track_artists,
        track_albums ( albums ( album_name, image ) )
      )
    `)
    .eq("user_id", userData.user.id);
  if (error) throw error;

  const songs: song[] = [];
  for (const entry of dbData) {
    /* the supabase api thinks that tracks() and albums() return an array of objects,
    but in reality, they only return one object. as a result, we have to do some
    pretty ugly typecasting to make the compiler happy */
    const track = entry.tracks as unknown as (typeof dbData)[0]["tracks"][0];
    const album = track.track_albums[0].albums as unknown as (typeof track)["track_albums"][0]["albums"][0];

    // transform the relevant information into a form that the frontend can parse
    songs.push({
        album_art_path: album.image,
        title: track.track_name,
        artists: track.track_artists,
        album: album.album_name
    });
  }

  // send the list of songs as a response, or null if there are no songs
  if (songs.length === 0) {
    return new Response(JSON.stringify(null), { headers: corsHeaders });
  } else {
    return new Response(JSON.stringify(songs), { headers: corsHeaders });
  }
}
Deno.serve(handleUserDataRequest);