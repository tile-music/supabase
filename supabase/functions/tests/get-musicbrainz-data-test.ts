// Import required libraries and modules
import { assert, assertEquals } from 'https://deno.land/std@0.192.0/testing/asserts.ts'

import { createSbServiceClient } from '../_shared/service_client.ts' 
// Set up the configuration for the Supabase client

const options = {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
    detectSessionInUrl: false,
  },
}

/**
 * TODO: Add types and get that working, for now its fine
 */

const testClientCreation = async () => {
  var client = await createSbServiceClient(options)
  // Test a simple query to the database
  const { data: table_data, error: table_error } = await client
    .from('played_tracks')
    .select('*')
    .limit(1)
  if (table_error) {
    throw new Error('Invalid Supabase client: ' + table_error.message)
  }
  assert(table_data, 'Data should be returned from the query.')
}

// Test the 'hello-world' function
const testMusicbrainzIsrc = async () => {
  var client  = await createSbServiceClient(options)

  // Invoke the 'hello-world' function with a parameter
  let { data: func_data, error: func_error } = await client.functions.invoke('get-musicbrainz-data', {
    body: { isrcReq: {
      isrc: 'ZZOPM2113006',
      albumName: 'Dad Vibes'
    }}, 
  })


  func_data = JSON.parse(func_data)
  // Check for errors from the function invocation
  if (func_error) {
    throw new Error('Invalid response: ' + func_error.message)
  }

  // Log the response from the function
  console.log(func_data)

  // Assert that the function returned the expected result
  assertEquals(func_data.id, "1ee62fa9-2c28-423f-9382-3ba5d4b2d2c6")
}

const testMusicbrainzIsrcFail = async () => { 
  var client = await createSbServiceClient(options)
  let { data: func_data, error: func_error } = await client.functions.invoke('get-musicbrainz-data', {
    body: { isrcReq: {
      isrc: 'usy282005364',
      albumName: 'Bug! EP'
    }}, 
  })
  func_data = JSON.parse(func_data)
  // Check for errors from the function invocation
  if (func_error) {
    throw new Error('Invalid response: ' + func_error.message)
  }

  // Log the response from the function
  console.log(func_data)

  // Assert that the function returned the expected result
  assertEquals(func_data.error, "No corresponding release found")

}

const testMusicbrainzUpc = async () => {
  var client  = await createSbServiceClient(options)

  // Invoke the 'hello-world' function with a parameter
  const { data: func_data, error: func_error } = await client.functions.invoke('get-musicbrainz-data', {
    body: { upcReq: {
      upc: '602435977161'
    }}, 
  })

  // Check for errors from the function invocation
  if (func_error) {
    throw new Error('Invalid response: ' + func_error.message)
  }
  console.log(func_data)
  // Log the response from the function
  console.log(JSON.stringify(await func_data))

  // Assert that the function returned the expected result
  assertEquals(func_data, {body: "Album may not exist in the Musicbrainz database"})

}




// Register and run the tests
Deno.test('Client Creation Test', testClientCreation)
Deno.test('musicbrainz Function Test for ensuring isrc results in an appropriate mbid', testMusicbrainzIsrc)
Deno.test('musicbrainz Function Test for ensuring isrc results in an appropiate error message ', testMusicbrainzIsrcFail)