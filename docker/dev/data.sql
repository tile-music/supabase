create table profiles (
  id uuid references auth.users not null,
  updated_at timestamp with time zone,
  username text unique,
  avatar_url text,
  website text,

  primary key (id),
  unique(username),
  constraint username_length check (char_length(username) >= 3)
);

alter table profiles enable row level security;

create policy "Public profiles are viewable by the owner."
  on profiles for select
  using ( auth.uid() = id );

create policy "Users can insert their own profile."
  on profiles for insert
  with check ( auth.uid() = id );

create policy "Users can update own profile."
  on profiles for update
  using ( auth.uid() = id );

-- Set up Realtime
begin;
  drop publication if exists supabase_realtime;
  create publication supabase_realtime;
commit;
alter publication supabase_realtime add table profiles;

-- Set up Storage
insert into storage.buckets (id, name)
values ('avatars', 'avatars');

create policy "Avatar images are publicly accessible."
  on storage.objects for select
  using ( bucket_id = 'avatars' );

create policy "Anyone can upload an avatar."
  on storage.objects for insert
  with check ( bucket_id = 'avatars' );

create policy "Anyone can update an avatar."
  on storage.objects for update
  with check ( bucket_id = 'avatars' );

# begin other 

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pgsodium" WITH SCHEMA "pgsodium";

COMMENT ON SCHEMA "public" IS 'standard public schema';

CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";

CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";
CREATE TYPE "public"."album" AS (
	"album_name" "text",
	"album_type" "text",
	"num_tracks" smallint,
	"release_date" "date",
	"artists" "text"[],
	"upc" "text",
    "image" "text"

);

ALTER TYPE "public"."album" OWNER TO "postgres";

CREATE DOMAIN "public"."isrc" AS "text" NOT NULL
	CONSTRAINT "isrc_check" CHECK ((VALUE ~* '^[A-Za-z]{2}-?\w{3}-?\d{2}-?\d{5}$'::"text"));

ALTER DOMAIN "public"."isrc" OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."add_played_track"("p_isrc" "public"."isrc", "p_popularity" smallint, "p_track_album" "public"."album", "p_track_artists" "text"[], "p_track_duration_ms" integer, "p_track_name" "text", "p_user_id" "uuid", "p_listened_at" timestamp without time zone) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$ BEGIN
    -- Insert the track if it does not exist
    INSERT INTO tracks (isrc, track_name, track_artists, track_duration_ms, track_album)
    VALUES (p_isrc, p_track_name, p_track_artists, p_track_duration_ms, p_track_album)
    ON CONFLICT (isrc) DO NOTHING;

    -- Insert into played_tracks
    INSERT INTO played_tracks (user_id, isrc, listened_at, popularity)
    VALUES (p_user_id, p_isrc, p_listened_at, p_popularity);
END;
$$;

ALTER FUNCTION "public"."add_played_track"("p_isrc" "public"."isrc", "p_popularity" smallint, "p_track_album" "public"."album", "p_track_artists" "text"[], "p_track_duration_ms" integer, "p_track_name" "text", "p_user_id" "uuid", "p_listened_at" timestamp without time zone) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."format_music_request"("isrc" "text", "album_name" "text", "upc" "text", "ean" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN jsonb_build_object(
    'isrcReq', CASE WHEN isrc IS NOT NULL THEN jsonb_build_object('isrc', isrc, 'albumName', album_name) END,
    'upcReq', CASE WHEN upc IS NOT NULL THEN jsonb_build_object('upc', upc) END,
    'eanReq', CASE WHEN ean IS NOT NULL THEN jsonb_build_object('ean', ean) END
  );
END;
$$;

ALTER FUNCTION "public"."format_music_request"("isrc" "text", "album_name" "text", "upc" "text", "ean" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$;

ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";

CREATE TABLE IF NOT EXISTS "public"."played_tracks" (
    "play_id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "listened_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "popularity" smallint,
    "isrc" "public"."isrc"
);

ALTER TABLE "public"."played_tracks" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."played_tracks_play_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER TABLE "public"."played_tracks_play_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."played_tracks_play_id_seq" OWNED BY "public"."played_tracks"."play_id";

CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "updated_at" timestamp with time zone,
    "username" "text",
    "full_name" "text",
    "avatar_url" "text",
    "website" "text",
    CONSTRAINT "username_length" CHECK (("char_length"("username") >= 3))
);

ALTER TABLE "public"."profiles" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."spotify_credentials" (
    "id" "uuid" NOT NULL,
    "refresh_token" "text"
);

ALTER TABLE "public"."spotify_credentials" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."tracks" (
    "isrc" "public"."isrc" NOT NULL,
    "track_name" "text" NOT NULL,
    "track_artists" "text"[] NOT NULL,
    "track_duration_ms" integer NOT NULL,
    "track_album" "public"."album" NOT NULL
);

ALTER TABLE "public"."tracks" OWNER TO "postgres";

CREATE OR REPLACE VIEW "public"."track_play_details" WITH ("security_invoker"='true') AS
 SELECT "pt"."play_id",
    "pt"."user_id",
    "pt"."listened_at",
    "pt"."popularity",
    "t"."isrc",
    "t"."track_name",
    "t"."track_artists",
    "t"."track_duration_ms",
    "t"."track_album"
   FROM ("public"."played_tracks" "pt"
     JOIN "public"."tracks" "t" ON ((("pt"."isrc")::"text" = ("t"."isrc")::"text")))
  ORDER BY "pt"."listened_at" DESC;

ALTER TABLE "public"."track_play_details" OWNER TO "postgres";

ALTER TABLE ONLY "public"."played_tracks" ALTER COLUMN "play_id" SET DEFAULT "nextval"('"public"."played_tracks_play_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."played_tracks"
    ADD CONSTRAINT "played_tracks_pkey" PRIMARY KEY ("play_id");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_username_key" UNIQUE ("username");

ALTER TABLE ONLY "public"."spotify_credentials"
    ADD CONSTRAINT "spotify_credentials_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."tracks"
    ADD CONSTRAINT "tracks_pkey" PRIMARY KEY ("isrc");

CREATE INDEX "idx_user_id" ON "public"."played_tracks" USING "btree" ("user_id");

CREATE OR REPLACE TRIGGER "get_mbid" AFTER INSERT ON "public"."tracks" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('http://192.168.1.253:54321/functions/v1/get-musicbrainz-data', 'POST', '{"Content-type":"application/json"}', '{"isrcReq":"{     isrc,    albumName   };"}', '5000');

ALTER TABLE ONLY "public"."played_tracks"
    ADD CONSTRAINT "fk_isrc" FOREIGN KEY ("isrc") REFERENCES "public"."tracks"("isrc");

ALTER TABLE ONLY "public"."played_tracks"
    ADD CONSTRAINT "played_tracks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."spotify_credentials"
    ADD CONSTRAINT "spotify_credentials_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

CREATE POLICY "Public profiles are viewable by everyone." ON "public"."profiles" FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile." ON "public"."profiles" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));

CREATE POLICY "Users can update own profile." ON "public"."profiles" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "id"));

CREATE POLICY "Users may add their own played tracks" ON "public"."played_tracks" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));

CREATE POLICY "Users may add their own spotify creds" ON "public"."spotify_credentials" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));

ALTER TABLE "public"."played_tracks" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."spotify_credentials" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users may delete their own played tracks" ON "public"."played_tracks" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));

CREATE POLICY "users may delete their own spotify creds" ON "public"."spotify_credentials" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "id"));

CREATE POLICY "users may select their own played tracks" ON "public"."played_tracks" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));

CREATE POLICY "users may select their own spotify creds" ON "public"."spotify_credentials" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "id"));

CREATE POLICY "users may update their own played tracks" ON "public"."played_tracks" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));

CREATE POLICY "users may update their own spotify creds" ON "public"."spotify_credentials" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "id"));

/*CREATE PUBLICATION "logflare_pub" WITH (publish = 'insert, update, delete, truncate');

ALTER PUBLICATION "logflare_pub" OWNER TO "supabase_admin";
*/
ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";

GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

GRANT ALL ON FUNCTION "public"."add_played_track"("p_isrc" "public"."isrc", "p_popularity" smallint, "p_track_album" "public"."album", "p_track_artists" "text"[], "p_track_duration_ms" integer, "p_track_name" "text", "p_user_id" "uuid", "p_listened_at" timestamp without time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."add_played_track"("p_isrc" "public"."isrc", "p_popularity" smallint, "p_track_album" "public"."album", "p_track_artists" "text"[], "p_track_duration_ms" integer, "p_track_name" "text", "p_user_id" "uuid", "p_listened_at" timestamp without time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_played_track"("p_isrc" "public"."isrc", "p_popularity" smallint, "p_track_album" "public"."album", "p_track_artists" "text"[], "p_track_duration_ms" integer, "p_track_name" "text", "p_user_id" "uuid", "p_listened_at" timestamp without time zone) TO "service_role";

GRANT ALL ON FUNCTION "public"."format_music_request"("isrc" "text", "album_name" "text", "upc" "text", "ean" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."format_music_request"("isrc" "text", "album_name" "text", "upc" "text", "ean" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."format_music_request"("isrc" "text", "album_name" "text", "upc" "text", "ean" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";

GRANT ALL ON TABLE "public"."played_tracks" TO "anon";
GRANT ALL ON TABLE "public"."played_tracks" TO "authenticated";
GRANT ALL ON TABLE "public"."played_tracks" TO "service_role";

GRANT ALL ON SEQUENCE "public"."played_tracks_play_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."played_tracks_play_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."played_tracks_play_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";

GRANT ALL ON TABLE "public"."spotify_credentials" TO "anon";
GRANT ALL ON TABLE "public"."spotify_credentials" TO "authenticated";
GRANT ALL ON TABLE "public"."spotify_credentials" TO "service_role";

GRANT ALL ON TABLE "public"."tracks" TO "anon";
GRANT ALL ON TABLE "public"."tracks" TO "authenticated";
GRANT ALL ON TABLE "public"."tracks" TO "service_role";

GRANT ALL ON TABLE "public"."track_play_details" TO "anon";
GRANT ALL ON TABLE "public"."track_play_details" TO "authenticated";
GRANT ALL ON TABLE "public"."track_play_details" TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";

RESET ALL;
