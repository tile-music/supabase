import { corsHeaders } from "./cors.ts";

/**
 * this type represents the expected request from the client
 */
export type MusicRequest = {
  isrcReq?: {
    isrc: string;
    albumName: string;
  };
  upcReq?: {
    upc: string;
  };
  eanReq?: {
    ean: string;
  };
};

/**
 * 
 * @param musicBrainzId the id of the album in the musicbrainz database
 * @returns the album art for the album if it exists
 * 
 * TODO: move this function somewhere else, im not gonna use it here
 */

async function fetchAlbumArt(musicBrainzId: string) {
  const response = await fetch(
    `http://coverartarchive.org/release/${musicBrainzId}`
  );
  console.log(response);
  const data = await response.json();
  console.log(data);
  return {
    body: data ? data : "Album may not exist in the Musicbrainz database",
  };
}
async function responseHelper(response: any, albumName: string) {
  let ret = {error: "No corresponding release found"}
  console.log(response);
  let filtered;
  if (response) {
    filtered = response.recordings[0]?.releases.reduce(
      (filtered: any, recording: any) => {
        if (recording.title === albumName) {
          filtered.push(recording);
        }
        return filtered;
      },
      []
    );
    console.log("FILTERED!!!!!", filtered);
    if (filtered && filtered.length > 0) ret = filtered[0]
    console.log(ret);
    return ret;
  }
}

export async function handleIsrcRequest(isrcReq: {
  isrc: string;
  albumName: string;
}) {
  const isrc = isrcReq.isrc;
  const response = await fetch(
    `https://musicbrainz.org/ws/2/recording?query=isrc:${isrc}&fmt=json`
  );
  const data = await response.json();

  const ret = await responseHelper(data, isrcReq.albumName);
  console.log(ret);

  return ret;
}

export async function handleUpcRequest(upcReq: { upc: string }) {
  // Handle UPC request
}

export async function handleEanRequest(eanReq: { ean: string }) {
  // Handle EAN request
}
