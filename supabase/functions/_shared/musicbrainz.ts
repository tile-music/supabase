import { corsHeaders } from "./cors.ts";
import { createSbServiceClient } from "./service_client.ts";

/**
 * this type represents the expected request from the endpoint
 */
export type MusicRequest = {
  isrcReq?: {
    isrc: string;
    match?: MatchMetrics;
  };
  upcReq?: {
    upc: string;
    match?: MatchMetrics;
  };
  eanReq?: {
    ean: string;
    match?: MatchMetrics;
  };
};

/**
 * this type represents contextual information returned by the spotify api
 * it is used for matching the album in the musicbrainz database
 */
export type MatchMetrics = {
  albumName: string;
  artistName: string[];
  numTracks: number;
  date: string;
};

/**
 * converts the request from the client to a format that can be used to query...
 * the musicbrainz api through associated functions
 * @param req the request from the client
 * @returns A MusicRequest object that can be used to query the musicbrainz api
 */
export function translateDBEntryToMusicRequest(req: any) {
  console.log(req);
  const match: MatchMetrics = {
    albumName: req.record.track_album.album_name,
    artistName: req.record.track_album.artists,
    numTracks: req.record.track_album.num_tracks,
    date: req.record.track_album.release_date,
  };
  return {
    isrcReq: {
      isrc: req.record.isrc,
      match: match,
    },
  };
}

/**
 * this function creates the db entry for the album art with the mbid as a key
 * @param artMap the map of mbids and associated album art
 * @returns an array of objects that can be inserted into the database
 */
function translateArtworkMapToDBEntry(artMap: Map<string, JSON>) {
  let ret: Array<{ mbid: string; images: JSON }> = [];
  for (const [key, value] of artMap) {
    ret.push({ mbid: key, images: value });
  }
  return ret;
}

/**
 * this function creates the db entry for the isrc and mbid
 * @param isrc the isrc of a given track 
 * @param artMap the map of mbids and associated album art
 * @returns an array of isrcs and mbids that can be inserted into the database
 * @todo instead of isrc make it a music request but that change is going...
 * to take a lot of doing
 */
function makeIsrcDBEntry(isrc: string, artMap: Map<string, JSON>) {
  let ret: Array<{ isrc: string; mbid: string }> = [];
  for (const [key, value] of artMap) {
    ret.push({ isrc: isrc, mbid: key });
  }
  return ret;
}

/**
 * this function puts album art into the database which takes the form of 2 entries in...
 * separate tables one with mbid and album art in the form of a json and the other with...
 * isrc and mbid
 * @param artMap the map of mbids to be passed to the two database entry functions
 * @param metadata the metadata associated with the request in the form of a music request
 */
export async function putArtworkInDB(
  artMap: Map<string, JSON>,
  metadata: MusicRequest
) {
  // put the artwork in the database\
  const isrc = metadata.isrcReq?.isrc;

  const options = {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  };
  const supabase = await createSbServiceClient(options);
  if (isrc) {
    const dbEntry = translateArtworkMapToDBEntry(artMap);
    const { data: q1data, error: q1error } = await supabase
      .from("art")
      .insert(dbEntry)
      .select();
    const isrcEntry = makeIsrcDBEntry(isrc, artMap);
    const { data: q2data, error: q2error } = await supabase
      .from("track_art")
      .insert(isrcEntry)
      .select();
    console.log(q1data, q1error, q2data, q2error);
  }
}

/**
 *
 * @param musicBrainzId the id of the album in the musicbrainz database
 * @returns the album art for the album if it exists
 */
async function fetchAlbumArt(musicBrainzId: string) {
  const response = await fetch(
    `http://coverartarchive.org/release/${musicBrainzId}`
  );
  console.log(response);
  return response;
}

/**
 * this function takes an array of mbids and calls handleAlbumArtHelper to get the album art
 * it then calls putArtworkInDB to put the album art in the database
 * @param data the array of mbids
 * @param metadata the metadata associated with the request in the form of a music request
 * @todo add a type for mbids, maybe have it  regex verify...
 */

async function handleAlbumArt(data: any[], metadata: MusicRequest) {
  let map: Map<string, JSON> | { error: string } = await handleAlbumArtHelper(
    data
  );
  if (map instanceof Map) {
    await putArtworkInDB(map, metadata);
  }
}

/**
 * this function calls fetch album art for each mbid in the array
 * @param data the array of mbids
 * @returns the map of mbids and associated album art responses
 */
export async function handleAlbumArtHelper(data: any[]) {
  let artMap: Map<string, JSON> = new Map<string, JSON>();
  if (data) {
    for (const mbid of data) {
      const art = await fetchAlbumArt(mbid);
      if (art.status === 200) {
        await art.json().then(async (data) => {
          artMap.set(mbid, await data);
        });
      } else {
        await art.body?.cancel();
      }
    }
  }
  console.log("artMap", artMap);
  if (artMap.size === 0) return { error: "No album art found" };
  else return artMap;
}

/**
 * this function "untangles the response from musicbrainz", 
 * @param response the response from the musicbrainz API
 * @returns an array of releases, see musicbrainz api docs...
 * for more info
 */
async function sortMbResponse(response: any) {
  console.log("called sort mbresponse");
  let ret = [];

  if (response) {
    console.log("count", response.count);
    for (let i = 0; i < response.count; i++) {
      for (let j = 0; j < response.recordings[i].releases.length; j++) {
        const release = response.recordings[i].releases[j];
        if (release) ret.push(release);
      }
    }
  }
  //console.log("ret", ret)
  return ret;
}

/**
 * this filters the response from the musicbrainz API to find the album that matches the reques
 * right now it only matches the album name and the number of tracks
 * @param response the response from the musicbrainz API
 * @param albumName the name of the album to be matched
 * @returns the matched releases through their mbids
 */
async function responseHelper(response: any, match: MusicRequest) {
  let sorted = await sortMbResponse(response);
  //console.log("SORTED" , sorted)

  let filtered: any[] = [];
  if (response) {
    sorted.map((element: any) => {
      if (
        element.title.toString().toLowerCase() ===
          match.isrcReq?.match?.albumName.toString().toLowerCase() &&
        element["track-count"] === match.isrcReq?.match?.numTracks
      ) {
        console.log("match", element);
        filtered.push(element.id);
      }
    });
    console.log("filtered", filtered);
    return filtered;
  }
}

/**
 * this is the main function for handling isrc to mbid reqests,
 * it fetches the data from musicbrainz and then calls response helper,
 * which then calls handleAlbumArt which sorts and puts the album art...
 * in the database
 * @param isrcReq the isrc request from the endpoint
 * @todo add a regex to prevent garbage from mb
 */

export async function handleIsrcRequest(isrcReq: {
  isrc: string;
  match: MatchMetrics;
}) {
  console.log(isrcReq);
  const isrc = isrcReq.isrc;
  const response = await fetch(
    `https://musicbrainz.org/ws/2/recording?query=isrc:${isrc}&fmt=json`
  );
  console.log(response);
  const data = await response.json();
  console.log;
  if (data.count === 0) return { error: "No corresponding release found" };
  else {
    const mbids = await responseHelper(data, { isrcReq: isrcReq });
    console.log(mbids);
    if (mbids) {
      console.log(await handleAlbumArt(mbids, { isrcReq: isrcReq }));
    }
    return mbids;
  }
}

export async function handleUpcRequest(upcReq: { upc: string }) {
  // Handle UPC request
}

export async function handleEanRequest(eanReq: { ean: string }) {
  // Handle EAN request
}
