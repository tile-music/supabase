import { corsHeaders } from "./cors.ts";

/**
 * this type represents the expected request from the client
 */
export type MusicRequest = {
  isrcReq?: {
    isrc: string;
    match: MatchMetrics;
  };
  upcReq?: {
    upc: string;
  };
  eanReq?: {
    ean: string;
  };
};

export type MatchMetrics = {
  albumName: string;
  artistName: string[];
  numTracks: number;
  date: string;
};

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
 *
 * @param musicBrainzId the id of the album in the musicbrainz database
 * @returns the album art for the album if it exists
 *
 * TODO: move this function somewhere else, im not gonna use it here
 */

export async function fetchAlbumArt(musicBrainzId: string) {
  const response = await fetch(
    `http://coverartarchive.org/release/${musicBrainzId}`
  );
  console.log(response);
  return response;
  /* const data =  response ? response.json() : null;
  console.log(data);
  return {
    body: data ? data : "Album may not exist in the Musicbrainz database",
  }; */
}

export async function findAlbumArt(data: any, map: Map<string, JSON>) {
  console.log("data", data);
  if(data.images instanceof Array) {
    console.log("data is array");
  }
  for (const id of data.images) {
    console.log("ids", id);
    const art = await fetchAlbumArt(id);
    console.log(art);
    if (art.status === 200) {
      await art.json().then((data) => map.set(id, data));
    }
  }
  return map;
}

async function handleAlbumArt(data : any[]){
  let artMap = new Map<string, JSON>();
  if(data){
    for(const mbid of data){
      const art = await fetchAlbumArt(mbid);
      if(art.status === 200){
        artMap = await art.json().then(async(data) => await findAlbumArt(data, artMap));
      }
    }
 
  }

}


async function sortMbResponse(response: any) {
  console.log("called sort mbresponse");
  let ret  = [];

  if (response) {
    console.log("count", response.count);
    for (let i = 0; i < response.count; i++) {
      console.log("loopin");
      //console.log("response", response.recordings[i].releases);
      //console.log("response", response.recordings[i])
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
 *
 * @todo implement another helper to streamline all the releases to be matched
 *
 * @param response the response from the musicbrainz API
 * @param albumName the name of the album to be matched
 * @returns the matched albums
 */
async function responseHelper(response: any, match: MusicRequest) {
  let sorted = await sortMbResponse(response);
  //console.log("SORTED" , sorted)

  let filtered: any[] = [];
  if (response) {
    sorted.map((element: any) => {
      if (
        element.title.toString().toLowerCase() ===
          match.isrcReq?.match.albumName.toString().toLowerCase() &&
        element["track-count"] === match.isrcReq?.match.numTracks
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
 *
 * @param isrcReq
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
    if(mbids) console.log(await handleAlbumArt(mbids));
    return mbids;
  }
}

export async function handleUpcRequest(upcReq: { upc: string }) {
  // Handle UPC request
}

export async function handleEanRequest(eanReq: { ean: string }) {
  // Handle EAN request
}
