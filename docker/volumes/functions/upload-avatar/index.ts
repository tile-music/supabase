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

  const formData = await req.formData();
  const avatar = formData.get("avatar") as File | null;

  if (!avatar) {
    return new Response("no avatar file provided",
      { status: 400, headers: corsHeaders });
  }

  if (avatar.size > 4 * 1024 * 1024) { // 4 MB limit
    return new Response("uploaded file is too large. maximum size is 4MB",
      { status: 400, headers: corsHeaders });
  }

  if (avatar.type !== "image/jpeg" && avatar.type !== "image/png") {
    return new Response("invalid file type. only JPEG and PNG are allowed",
      { status: 400, headers: corsHeaders });
  }

  // generate a uuid for the avatar file
  const uuid = crypto.randomUUID();

  const { error: uploadError } = await supabase.storage.from('avatars')
    .upload(uuid, avatar);
  if (uploadError) {
    log(2, `Error uploading avatar: ${uploadError.message}`);
    return new Response("server error while uploading avatar",
      { status: 500, headers: corsHeaders },
    );
  }

  // update the avatar URL in the user's profile
  const { error: profileError } = await supabase
    .from("profiles")
    .update({ avatar_url: `assets/public/avatars/${uuid}` })
    .eq("id", userData.user.id)
  
  if (profileError) {
    log(2, `Error updating profile avatar URL: ${profileError.message}`);
    return new Response("server error while updating profile",
      { status: 500, headers: corsHeaders },
    );
  }

  return new Response(
    "successfully uploaded avatar",
    { status: 200, headers: { ...corsHeaders } },
  );
}
Deno.serve(handleUploadAvatar);