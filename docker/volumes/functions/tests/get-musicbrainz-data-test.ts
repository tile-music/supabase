// Import required libraries and modules
import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.192.0/testing/asserts.ts";

import { createSbServiceClient } from "../_shared/service_client.ts";
import { handleAlbumArtHelper, putArtworkInDB } from "../_shared/musicbrainz.ts";
// Set up the configuration for the Supabase client

const options = {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
    detectSessionInUrl: false,
  },
};

/**
 * TODO: Add types and get that working, for now its fine
 */

var client = await createSbServiceClient(options);
export const testClientCreation = async () => {
  // Test a simple query to the database
  const { data: table_data, error: table_error } = await client
    .from("played_tracks")
    .select("*")
    .limit(1);
  if (table_error) {
    throw new Error("Invalid Supabase client: " + table_error.message);
  }
  assert(table_data, "Data should be returned from the query.");
};

const testHelper = (
  isrcIn: string,
  trackName: string,
  artistName: string,
  albumName: string,
  numTracks: number,
  release_date: string,
  trackDurationMs: number
) => {
  return {
    body: {
      type: "INSERT",
      table: "tracks",
      record: {
        isrc: isrcIn,
        track_name: trackName,
        track_album: {
          upc: null,
          artists: [artistName],
          album_name: albumName,
          album_type: "album",
          num_tracks: numTracks,
          release_date: release_date,
        },
        track_artists: [artistName],
        track_duration_ms: trackDurationMs,
      },
      schema: "public",
      old_record: null,
    },
  };
};

// Test the 'hello-world' function
export const testMusicbrainzIsrc = async () => {
  // Invoke the 'hello-world' function with a parameter
  let { data: func_data, error: func_error } = await client.functions.invoke(
    "get-musicbrainz-data",
    testHelper(
      "USCA29600428",
      "Pepper",
      "Butthole Surfers",
      "Electriclarryland",
      13,
      "1995-12-31",
      297266
    )
  );

  func_data = JSON.parse(func_data);
  // Check for errors from the function invocation
  if (func_error) {
    throw new Error("Invalid response: " + func_error.message);
  }

  // Log the response from the function
  console.log(func_data);
  //await findAlbumArt(func_data);

  // Assert that the function returned the expected result
  assertEquals(func_data[0], "985410f4-9173-43b8-b5c0-07561856dea5");
};

/* let { data: func_data, error: func_error } = await client.functions.invoke(
  "get-musicbrainz-data",
  testHelper(
    "USCA29600428",
    "Pepper",
    "Butthole Surfers",
    "Electriclarryland",
    13,
    "1995-12-31",
    297266
  )
);

func_data = JSON.parse(func_data);
// Check for errors from the function invocation
// Log the response from the function
console.log(func_data);
const albumMap = await findAlbumArt(func_data);
console.log(albumMap); */

export const testMusicbrainzImages = async () => {
  // Invoke the 'hello-world' function with a parameter
  let data = [
    "985410f4-9173-43b8-b5c0-07561856dea5",
    "b7b86692-be84-486e-b641-24fa713ab624",
    "6cc778b9-c78f-33bb-b16e-d622548852f9",
    "cf772800-18f8-3f5f-bfbd-c99b80f4731f",
    "b27669ba-a17c-467c-bd1d-6c0cfc9dc5bf",
    "a4702c2a-3b5e-4b8f-84bd-ccb86074bc1b",
    "f9202fb3-20a9-4e48-81ef-b1b9cd708403",
    "6564c73b-5aa0-4b0e-a98a-11c87eeda874",
  ];
  
  let result = await handleAlbumArtHelper(data);
  if(result instanceof Map) await putArtworkInDB(result, {isrcReq: {isrc: "USCA29600428"}});
  //console.log(result);

  assert(result instanceof Map, "Result should be a map");

  // Assert that the function returned the expected result
  //assertEquals(func_data[0], "985410f4-9173-43b8-b5c0-07561856dea5");
};

export const testMusicbrainzIsrc1 = async () => {
  // Invoke the 'hello-world' function with a parameter
  let { data: func_data, error: func_error } = await client.functions.invoke(
    "get-musicbrainz-data",
    testHelper(
      "USMTD2100003",
      "christine",
      "Lucy Dacus",
      "Home Video",
      11,
      "2021-06-24",
      153504
    )
  );

  func_data = JSON.parse(func_data);
  // Check for errors from the function invocation
  if (func_error) {
    throw new Error("Invalid response: " + func_error.message);
  }

  // Log the response from the function
  console.log(func_data);

  // Assert that the function returned the expected result
  assertEquals(func_data[0], "01348579-296b-4801-a022-28608f8eece0");
};

export const testMusicbrainzIsrcFail = async () => {
  let { data: func_data, error: func_error } = await client.functions.invoke(
    "get-musicbrainz-data",
    testHelper(
      "usy282005364",
      "Plum",
      "Bug",
      "Bug! EP",
      5,
      "2021-01-16",
      197800
    )
  );
  func_data = JSON.parse(func_data);
  // Check for errors from the function invocation
  if (func_error) {
    throw new Error("Invalid response: " + func_error.message);
  }

  // Log the response from the function
  console.log(func_data);

  // Assert that the function returned the expected result
  assertEquals(func_data.error, "No corresponding release found");
};

export const testMusicbrainzUpc = async () => {
  var client = await createSbServiceClient(options);

  // Invoke the 'hello-world' function with a parameter
  const { data: func_data, error: func_error } = await client.functions.invoke(
    "get-musicbrainz-data",
    {
      body: {
        upcReq: {
          upc: "602435977161",
        },
      },
    }
  );

  // Check for errors from the function invocation
  if (func_error) {
    throw new Error("Invalid response: " + func_error.message);
  }
  console.log(func_data);
  // Log the response from the function
  console.log(JSON.stringify(await func_data));

  // Assert that the function returned the expected result
  assertEquals(func_data, {
    body: "Album may not exist in the Musicbrainz database",
  });
};
Deno.test("album art test", testMusicbrainzImages);

// Register and run the tests
Deno.test("Client Creation Test", testClientCreation);
Deno.test(
  "musicbrainz Function Test for ensuring isrc results in an appropriate mbid",
  testMusicbrainzIsrc
);
Deno.test(
  "musicbrainz Function Test for ensuring isrc results in an appropriate mbid",
  testMusicbrainzImages
);
Deno.test(
  "musicbrainz Function Test for ensuring isrc results in an appropriate mbid",
  testMusicbrainzIsrc1
);
Deno.test(
  "musicbrainz Function Test for ensuring isrc results in an appropiate error message ",
  testMusicbrainzIsrcFail
);
