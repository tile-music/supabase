import { SupabaseClient } from "@supabase/supabase-js";

import * as dotenv from "dotenv";

import { Album, Client, Player, Track, User } from "spotify-api.js";


dotenv.config({path: "../../../../.env"});
console.log(process.env)
function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
const sbClient = new SupabaseClient(process.env.API_EXTERNAL_URL, process.env.SERVICE_ROLE_KEY, {db:{schema: "prod"}});
async function fetchTrackByISRC(token: string, isrc: string): Promise<any> {
  const endpoint = `https://api.spotify.com/v1/search?q=isrc%3A${encodeURIComponent(isrc)}&type=track`;

  try {
    const response = await fetch(endpoint, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      if(response && response.status == 429){
        console.log("Rate limit exceeded");
        const retryAfter : number | null = response.headers?.get("Retry-After") ? parseInt(response.headers.get("Retry-After")) : null;
        if(retryAfter){
          await sleep(retryAfter * 1000);
          return fetchTrackByISRC(token, isrc);
        } else {
          throw new Error("something other than rate limit is fucked");
        }
      }
    }

    const data = await response.json();
    return data;
  } catch (error) {
    console.error("Error fetching track by ISRC:", error);
    throw error;
  }
}


async function main() {
  const {data: trackAlbumsData, error: trackAlbumsError} = await sbClient.schema("prod").from("track_albums").select("*");
    const {data: albumsData, error: albumsError} = await sbClient.schema("prod").from("albums").select("*");
    const {data: tracksData, error: tracksError} = await sbClient.schema("prod").from("tracks").select("*");
    const trackAlbumsMap = new Map<number, number>();
    const albumsMap = new Map<number, any>();
    const tracksMap = new Map<number, any>();
  try{
    const spotifyClient = await Client.create({
      refreshToken: true,
      token: {
        clientID: process.env.SP_CID as string,
        clientSecret: process.env.SP_SECRET as string,
        refreshToken: process.env.SP_TOKEN as string
      },
      onRefresh: () => {
        console.log(
          `Token has been refreshed. New token: ${this.client.token}!`
        );
      },
    });

    
    console.log(tracksData);

    albumsData.forEach((item: { album_id: number; album_name: string; album_type: string; num_tracks: number; artists: string[]; genre: string; upc: string; ean: string; image: string; release_year: number; release_month: number; release_day: number; spotify_id: string }) => {
      albumsMap.set(item.album_id, item);
    });
    tracksData.forEach((item: { track_id: number; isrc: string; track_name: string; track_artists: string[]; track_duration_ms: number; spotify_id: string }) => {
      tracksMap.set(item.track_id, item);
    })
    console.log(albumsData)
    trackAlbumsData.forEach((item: { track_id: number; album_id: number }) => {
      trackAlbumsMap.set(item.track_id, item.album_id);
    });

    
    for (const [trackId, item] of tracksMap.entries()) {
      //console.log(item);
  
      try {
          const data = await fetchTrackByISRC(spotifyClient.token, item.isrc);
  
          for (const track of data.tracks.items) {
              if (track.external_ids.isrc === item.isrc) {
                  const albumId = trackAlbumsMap.get(trackId);
                  const albumData = albumsMap.get(albumId) || {};
                  const trackData = tracksMap.get(trackId) || {};
  
                  if (!albumData.spotify_id) {
                      albumData.spotify_id = track.album.id;
                      const { error } = await sbClient.from("albums").update({ spotify_id: track.album.id }).eq("album_id", albumId);
                      albumsMap.set(albumId, albumData);
                  }
  
                  if (!trackData.spotify_id) {
                      trackData.spotify_id = track.id;
                      const { error } = await sbClient.from("tracks").update({ spotify_id: track.id }).eq("track_id", trackId);
                      tracksMap.set(trackId, trackData);
                  }
  
                  if (albumData.spotify_id && trackData.spotify_id) {

                      console.log("Successfully matched", track);
                      break;
                  }
                  console.log("Failed to match", track);
              }
          }
      } catch (error) {
          console.error(`Error processing track ID ${trackId}:`, error);
      }
  }
  
    

  } catch (e) {
    console.log(e);
  } finally{
    console.log("done");

  }
}

main();