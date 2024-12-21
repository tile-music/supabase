import { corsHeaders } from "../_shared/cors.ts";
import { createSbClient } from "../_shared/client.ts";
import type { SongInfo, AlbumInfo } from "../../../../../lib/Song.ts";
import type { DisplayDataRequest, RankOutput } from "../../../../../lib/Request.ts";

/**
 * Handles requests for art display data, querying a user's list of played tracks and
 * sorting/filtering them based on request parameters.
 * 
 * @param _req - The request object.
 * @returns A response object containing a sorted list of played tracks, or null if empty.
 */
async function handleUserDataRequest(_req: Request) {
  // create authenticated supabase client scoped to the "prod" schema
  const authHeader = _req.headers.get("Authorization")!;
  const supabase = await createSbClient(authHeader, "prod");
  
  // get user data, since we need it to filter played tracks to the specific user
  const { data: userData } = await supabase.auth.getUser();
  if (!userData.user) {
    return new Response("Unable to fetch user",
      { status: 401, headers: corsHeaders });
  }

  // get search filters
  let body;
  try { body = validateDisplayDataRequest(await _req.json()); }
  catch (error) { return new Response(error, { status: 400, headers: corsHeaders }); }

  // fetch the track and album information for the current user's played tracks
  let query = supabase
  .from("played_tracks")
  .select(`
    listened_at,
    tracks ( isrc, track_name, track_artists, track_duration_ms,
      track_albums ( albums ( album_name, num_tracks, release_day,
        release_month, release_year, artists, image ) )
    )
  `)
  .eq("user_id", userData.user.id);


  // if start date is provided, filter out listens before start date
  if (body.date.start) {
    console.log(body.date.start);
    const startTimestamp = Math.floor(new Date(body.date.start).getTime());
    console.log("timestamp:", startTimestamp);
    query = query.gte("listened_at", startTimestamp);
  }

  // if end date is provided, filter out listens after end date (inclusive)
  if (body.date.end) {
    const endDate = new Date(body.date.end);
    endDate.setDate(endDate.getDate() + 1);
    query = query.lte("listened_at", Math.floor(endDate.getTime()));
  }

  // execute query
  const { data: dbData, error } = await query;
  if (error) throw error;

  const songs: SongInfo[] = [];
  for (const entry of dbData) {
    // the supabase api thinks that tracks() and track_albums() return an array of objects,
    // but in reality, they only return one object. as a result, we have to do some
    // pretty ugly typecasting to make the compiler happy
    const track = entry.tracks as unknown as (typeof dbData)[0]["tracks"][0];
    const album = track.track_albums[0].albums as unknown as (typeof track)["track_albums"][0]["albums"][0];

    // extract album information
    const albumInfo: AlbumInfo = {
      title: album.album_name,
      tracks: album.num_tracks,
      release_day: album.release_day,
      release_month: album.release_month,
      release_year: album.release_year,
      artists: album.artists,
      image: album.image
    };

    // extract song information
    const songInfo: SongInfo = {
      isrc: track.isrc,
      title: track.track_name,
      artists: track.track_artists,
      duration: track.track_duration_ms,
      listened_at: entry.listened_at,
      albums: [albumInfo]
    };

    songs.push(songInfo);
  }

  // filter songs by the requested number of cells if given
  let rankedSongs = rankSongs(songs, body.aggregate, body.rank_determinant);
  if (body.num_cells) {
    if (rankedSongs.length < body.num_cells) {
      return new Response("Not enough listening data for the number of cells chosen.",
        { status: 400, headers: corsHeaders});
    }
    rankedSongs = rankedSongs.slice(0, body.num_cells);
  }

  // send the list of songs as a response, or null if there are no songs
  if (songs.length === 0) {
    return new Response(JSON.stringify(null), { headers: corsHeaders });
  } else {
    return new Response(JSON.stringify(rankedSongs), { headers: corsHeaders });
  }
}
Deno.serve(handleUserDataRequest);

/**
 * Aggregates a list of songs based on a chosen aggregate and
 * sorts them based on a chosen determinant
 * 
 * @param songs the list of songs listened to by the user
 * @returns a sorted list of objects containing the song and its rank quantity
 */
function rankSongs(
  songs: SongInfo[],
  aggregate: DisplayDataRequest["aggregate"],
  determinant: DisplayDataRequest["rank_determinant"]
): RankOutput {
  // return empty array if listening data is empty
  if (!songs || !songs.length) return [];

  // increment rank quantity differently based on determinant
  let increment: (s: SongInfo) => number;
  if (determinant === "listens") increment = (_s: SongInfo) => 1;
  else if (determinant === "time") increment = (s: SongInfo) => s.duration;
  else throw "Invalid aggregate";

  // tabulate number of listens based on chosen aggregate
  const ranks: { [x: string]: number } = {};
  const songRanking: { [x: string]: SongInfo } = {}
  for (const song of songs) {
      let rank: string;
      switch(aggregate){
          case "song":
              rank = song.isrc;
              break;
          case "album":
              rank = song.albums[0].image;
              break;
          default: throw "Invalid aggregate"
      }

      // create new entry in rankings or increment current entry
      if (!ranks[rank]) {
          ranks[rank] = increment(song);
          songRanking[rank] = song;
      } else ranks[rank]+= increment(song);
  }
  
  // translate isrc back into song
  const output: RankOutput = [];
  for (const identifier in ranks)
      output.push({ song: songRanking[identifier], quantity: ranks[identifier] });

  // sort by number of plays in descending order
  output.sort((a, b) => { return b.quantity - a.quantity; });
  return output;
}

/**
 * Verifies that the format of a request body matches that of DisplayDataRequest
 * 
 * @param req The raw request body
 * @returns A request body that matches the format of DisplayDataRequest,
 *  or an error if unsuccessful
 */
function validateDisplayDataRequest(req: unknown): DisplayDataRequest {
    if (typeof req !== "object" || req == null) throw "Invalid request: body is not an object";

    // aggregate
    if (!("aggregate" in req)) throw "Invalid request: missing aggregate";
    if (req.aggregate !== "song" && req.aggregate !== "album")
        throw "Invalid request: aggregate is invalid";

    // num_cells
    if (!("num_cells" in req)) throw "Invalid request: missing number of cells";
    if (req.num_cells !== null && (typeof req.num_cells !== "number" ||
        !Number.isInteger(req.num_cells) || req.num_cells < 1))
        throw "Invalid request: number of cells is invalid";

    // date
    if (!("date" in req) || typeof req.date !== "object" || req.date == null)
        throw "Invalid request: missing date";

    if (!("start" in req.date)) throw "Invalid request: start date is missing";
    if (!validateDate(req.date.start)) throw 'Invalid request: start date is invalid';

    if (!("end" in req.date)) throw "Invalid request: end date is missing";
    if (!validateDate(req.date.end)) throw "Invalid request: end date is invalid";

    if (!("rank_determinant" in req)) throw "Invalid request: rank determinant is missing";
    if (req.rank_determinant !== "listens" && req.rank_determinant !== "time")
        throw "Invalid request: rank determinant is invalid";

    return req as DisplayDataRequest;
}

/**
 * Ensures that a given HTML date input value is valid.
 * 
 * @param dateString The string to verify
 * @returns Whether or not the string is a valid HTML data input value
 */
function validateDate(dateString: unknown): boolean {
  if (dateString === null) return true;
  if (typeof dateString !== "string") return false;

  // make sure date format is valid
  const dateRegex = /^\d{4}-(0[1-9]|1[0-2])-([0-2]\d|3[0-1])/;
  if (!dateRegex.test(dateString)) return false;

  // make sure date is valid using JS date parsing
  // not super reliable, which is why it's loosely tested earlier
  const date = new Date(dateString);
  if (isNaN(date.getTime())) return false;

  return true;
}