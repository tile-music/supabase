import { corsHeaders } from "../_shared/cors.ts";
import { createSbClient } from "../_shared/client.ts";
import type { SongInfo } from "../../../../../lib/Song.ts";
import type { ContextDataRequest, RankOutput, ContextDataResponse } from "../../../../../lib/Request.ts";
import { constructQuery, processPlayedTracksData } from "../_shared/query.ts";

/**
 * Handles requests for art display context menu data, querying a user's list 
 * of played tracks and sorting/filtering them based on request parameters.
 * 
 * @param _req - The request object.
 * @returns A response object containing a sorted list of played tracks, or null if empty.
 */
async function handleContextDataRequest(_req: Request) {
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
  try {
    body = validateContextDataRequest(await _req.json());
  }
  catch (error) {
    return new Response(error as string, { status: 400, headers: corsHeaders })
  }

  // fetch the track and album information for the current user's played tracks
  let query = constructQuery(supabase, userData.user.id)
  .eq("tracks.track_albums.albums.image", body.upc);


  // if start date is provided, filter out listens before start date
  if (body.date.start) query = query.gte("listened_at", body.date.start);

  // if end date is provided, filter out listens after end date (inclusive)
  if (body.date.end) {
    const endTimestamp = body.date.end + 86400000 // add 24 hours
    query = query.lte("listened_at", endTimestamp);
  }

  // execute query
  const { data: dbData, error } = await query;
  if (error) throw error;

  // process songs into SongInfo and AlbumInfo types
  const songs = processPlayedTracksData(dbData);

  // filter songs by the requested number of cells if given
  const rankedSongs = rankSongsFromAlbum(songs, body.rank_determinant);

  // send the list of songs as a response, or null if there are no songs
  if (songs.length >= 0) {
    const response: ContextDataResponse = { songs: rankedSongs };
    return new Response(JSON.stringify(response), { headers: corsHeaders });
  } else {
    return new Response("Unable to retrieve song data.", { status: 500, headers: corsHeaders});
  }
}
Deno.serve(handleContextDataRequest);

/**
 * Aggregates a list of songs based on a chosen aggregate and
 * sorts them based on a chosen determinant
 * 
 * @param songs the list of songs listened to by the user
 * @returns a sorted list of objects containing the song and its rank quantity
 */
function rankSongsFromAlbum(
  songs: SongInfo[],
  determinant: ContextDataRequest["rank_determinant"]
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
        const rank = song.isrc;

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
export function validateContextDataRequest(req: unknown): ContextDataRequest {
    if (typeof req !== "object" || req == null) throw "Invalid request: body is not an object";

    if (!("upc" in req) || typeof req.upc !== "string" || req.upc == null)
        throw "Invalid request: missing or invalid UPC";

    // date
    if (!("date" in req) || typeof req.date !== "object" || req.date == null)
        throw "Invalid request: missing date";

    if (!("start" in req.date) || req.date.start === undefined) throw "Invalid request: start date is missing";
    if (req.date.start != null && !Number.isInteger(req.date.start)) throw 'Invalid request: start date is invalid';

    if (!("end" in req.date) || req.date.end === undefined) throw "Invalid request: end date is missing";
    if (req.date.end != null && !Number.isInteger(req.date.end)) throw "Invalid request: end date is invalid";

    if (req.date.start !== null && req.date.end !== null &&
        req.date.end! < req.date.start!) throw "Invalid request: end date is before start date";

    // rank determinant
    if (!("rank_determinant" in req)) throw "Invalid request: rank determinant is missing";
    if (req.rank_determinant !== "listens" && req.rank_determinant !== "time")
        throw "Invalid request: rank determinant is invalid";

    return req as ContextDataRequest;
}