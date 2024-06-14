import { createSbClient } from "../_shared/client.ts";
import { assert, assertEquals } from 'https://deno.land/std@0.192.0/testing/asserts.ts'

const client = await createSbClient();

export const testCheckSpotifyTrue = async () => {
  await client.auth.signInWithPassword({
    email: Deno.env.get("SB_TEST_EMAIL")!,
    password: Deno.env.get("SB_TEST_PASSWORD")!,
  });
  const {data:{session} }  = await client.auth.getSession()

  console.log(session)

  //if (userError) throw new Error("Invalid response: " + userError.message);
  let token : string
  if(session) token = session.access_token as string;
  else throw new Error("Invalid response: " + session);
  // Invoke the 'hello-world' function with a parameter
  let { data: funcData, error: funcError } = await client.functions.invoke(
    "check-spotify",
    {headers: {Authorization: "Bearer " + token}}
  );

  funcData = JSON.parse(funcData);
  // Check for errors from the function invocation
  await client.auth.signOut().catch(console.error);
  if (funcError) {
    throw new Error("Invalid response: " + funcError.message);
  }

  console.log(funcData);

  // Assert that the function returned the expected result
  assertEquals(funcData, 1);
  client.auth.signOut()
  console.log(await client.auth.getSession())
};
Deno.test('Client Creation Test',  testCheckSpotifyTrue)  


