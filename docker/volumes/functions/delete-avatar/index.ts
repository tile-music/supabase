import { corsHeaders } from "../_shared/cors.ts";
import { log } from "../_shared/log.ts";
import { createSbClient } from "../_shared/client.ts";

/**
 * Handles requests to upload a user's avatar image to Supabase storage.
 * Validates the uploaded file, checking its size and type.
 * 
 * @param _req - The request object.
 * @returns A response object containing either a success message or an error message.
 */
async function handleUploadAvatar(req: Request) {
  // create authenticated supabase client scoped to the "public" schema
  const authHeader = req.headers.get("Authorization")!;
  const supabase = await createSbClient(authHeader, "public");
  
  // get user data
  const { data: userData } = await supabase.auth.getUser();
  if (!userData.user) {
    log(4, "Unable to fetch user");
    return new Response("Unable to fetch user",
      { status: 401, headers: corsHeaders });
  }

  // get previous avatar URL from profile data
  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("avatar_url")
    .eq("id", userData.user.id)
    .single();
  
  if (profileError) {
    log(2, `Error updating profile avatar URL: ${profileError.message}`);
    return new Response("server error while fetching profile",
      { status: 500, headers: corsHeaders },
    );
  }

  // extract the UUID from the previous avatar URL
  const uuid = profile?.avatar_url?.split("/").pop() || "";

  if (!uuid) {
    log(2, "No previous avatar URL found");
    return new Response("no previous avatar URL found",
      { status: 400, headers: corsHeaders });
  }

  // delete the previous avatar file from storage
  const { error: deleteError } = await supabase.storage.from('avatars')
    .remove([uuid]);
  
  if (deleteError) {
    log(2, `Error deleting previous avatar: ${deleteError.message}`);
    return new Response("server error while deleting previous avatar",
      { status: 500, headers: corsHeaders },
    );
  }

  // remove the avatar URL from the user's profile
  const { error: updateError } = await supabase
    .from("profiles")
    .update({ avatar_url: null })
    .eq("id", userData.user.id);

  if (updateError) {
    log(2, `Error updating profile avatar URL: ${updateError.message}`);
    return new Response("server error while updating profile",
      { status: 500, headers: corsHeaders },
    );
  }

  // const { error: uploadError } = await supabase.storage.from('avatars')
  //   .upload(uuid, avatar);
  // if (uploadError) {
  //   log(2, `Error uploading avatar: ${uploadError.message}`);
  //   return new Response("server error while uploading avatar",
  //     { status: 500, headers: corsHeaders },
  //   );
  // }

  return new Response(
    "successfully removed avatar",
    { status: 200, headers: { ...corsHeaders } },
  );
}
Deno.serve(handleUploadAvatar);