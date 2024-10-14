

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






CREATE SCHEMA IF NOT EXISTS "prod";


ALTER SCHEMA "prod" OWNER TO "postgres";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE SCHEMA IF NOT EXISTS "test";


ALTER SCHEMA "test" OWNER TO "postgres";


CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "prod"."add_played_track_type" AS (
	"track" "jsonb",
	"track_album" "jsonb",
	"p_listened_at" timestamp with time zone
);


ALTER TYPE "prod"."add_played_track_type" OWNER TO "postgres";


CREATE TYPE "prod"."album_type" AS (
	"album_name" "text",
	"album_type" "text",
	"num_tracks" integer,
	"release_date" "date",
	"artists" "text"[],
	"genre" "text"[],
	"upc" "text",
	"ean" "text",
	"album_isrc" "text",
	"image" "jsonb"
);


ALTER TYPE "prod"."album_type" OWNER TO "postgres";


CREATE DOMAIN "prod"."isrc" AS "text" NOT NULL
	CONSTRAINT "isrc_check" CHECK ((VALUE ~* '^[A-Za-z]{2}-?\w{3}-?\d{2}-?\d{5}$'::"text"));


ALTER DOMAIN "prod"."isrc" OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."clear_test_tables"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Disable foreign key checks to avoid dependency issues during truncation
    SET session_replication_role = 'replica';

    -- Truncate all test schema tables
    TRUNCATE TABLE
        test.albums,
        test.track_albums,
        test.tracks,
        test.played_tracks
    RESTART IDENTITY;  -- Resets the sequences (IDs)

    -- Re-enable foreign key checks
    SET session_replication_role = 'origin';

    RAISE NOTICE 'Test schema tables have been cleared.';
END;
$$;


ALTER FUNCTION "public"."clear_test_tables"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."duplicate_view"("src_schema" "text", "dest_schema" "text", "view_name" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    view_definition TEXT;
BEGIN
    -- Get the definition of the view from the source schema
    SELECT pg_get_viewdef(format('%I.%I', src_schema, view_name), true)
    INTO view_definition;

    -- Replace the schema in the view definition
    view_definition := REPLACE(view_definition, src_schema, dest_schema);

    -- Create the view in the destination schema
    EXECUTE format('CREATE VIEW %I.%I AS %s', dest_schema, view_name, view_definition);
END;
$$;


ALTER FUNCTION "public"."duplicate_view"("src_schema" "text", "dest_schema" "text", "view_name" "text") OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "test"."add_played_track"("p_track_json" "jsonb", "p_album_json" "prod"."album_type", "p_listened_at" timestamp with time zone, "p_user_id" "uuid", "p_environment" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $_$
DECLARE
    v_track prod.track_type;
    v_album prod.album_type;
    schema_name text := CASE
        WHEN p_environment = 'test' THEN 'test'
        ELSE 'prod'
    END;
    v_album_id bigint;  -- Variable to store the album_id after inserting the album
    v_track_id bigint;  -- Variable to store the track_id after inserting the track
BEGIN
    -- Map JSON fields to track_type custom type
    v_track := ROW(
        p_track_json->>'isrc',
        p_track_json->>'track_name',
        ARRAY(SELECT jsonb_array_elements_text(p_track_json->'track_artists')),
        (p_track_json->>'track_duration_ms')::integer
    )::prod.track_type;

    -- Map JSON fields to album_type custom type
    v_album := ROW(
        p_album_json->>'album_name',
        p_album_json->>'album_type',
        (p_album_json->>'num_tracks')::smallint,
        (p_album_json->>'release_date')::date,
        ARRAY(SELECT jsonb_array_elements_text(p_album_json->'artists')),
        ARRAY(SELECT jsonb_array_elements_text(p_album_json->'genre')),
        p_album_json->>'upc',
        p_album_json->>'ean',
        p_album_json->>'album_isrc',
        (p_album_json->>'popularity')::smallint,
        p_album_json->'image'
    )::prod.album_type;

    -- Insert into the albums table
    EXECUTE format('
        INSERT INTO %I.albums (album)
        VALUES ($1)
        ON CONFLICT DO NOTHING
        RETURNING album_id', schema_name)
    USING v_album INTO v_album_id;

    -- Fetch the existing album_id if no insertion occurred
    IF v_album_id IS NULL THEN
        EXECUTE format('
            SELECT album_id INTO v_album_id
            FROM %I.albums
            WHERE album = $1', schema_name)
        USING v_album;
    END IF;

    -- Raise an exception if album_id is still NULL
    IF v_album_id IS NULL THEN
        RAISE EXCEPTION 'Album not found after insertion attempt: %', v_album;
    END IF;

    -- Insert into the tracks table
    EXECUTE format('
        INSERT INTO %I.tracks (track)
        VALUES ($1)
        ON CONFLICT DO NOTHING
        RETURNING track_id', schema_name)
    USING v_track INTO v_track_id;

    -- Fetch the track_id if no insertion occurred
    IF v_track_id IS NULL THEN
        EXECUTE format('
            SELECT track_id INTO v_track_id
            FROM %I.tracks
            WHERE track->>''isrc'' = $1', schema_name)
        USING v_track.isrc;
    END IF;

    -- Insert into the track_albums table
    EXECUTE format('
        INSERT INTO %I.track_albums (track_id, album_id)
        VALUES ($1, $2)
        ON CONFLICT DO NOTHING', schema_name)
    USING v_track_id, v_album_id;

    -- Insert into the played_tracks table
    EXECUTE format('
        INSERT INTO %I.played_tracks (user_id, isrc, listened_at, popularity)
        VALUES ($1, $2, $3, $4)', schema_name)
    USING p_user_id, v_track.isrc, p_listened_at, v_album.popularity;

END;
$_$;


ALTER FUNCTION "test"."add_played_track"("p_track_json" "jsonb", "p_album_json" "prod"."album_type", "p_listened_at" timestamp with time zone, "p_user_id" "uuid", "p_environment" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "test"."bulk_add_played_track"("p_track_info" "prod"."add_played_track_type"[], "p_user_id" "uuid", "p_environment" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    i integer;  -- Index for looping through the array
BEGIN
    -- Loop through the array of played track info
    FOR i IN 1 .. array_length(p_track_info, 1) LOOP
        -- Call the single add_played_track function for each track info
        PERFORM test.add_played_track(
            p_track_info[i].track,                -- Track information
            p_track_info[i].track_album,          -- Album information
            p_track_info[i].p_listened_at,        -- When the track was played
            p_user_id,                            -- User ID passed as parameter
            p_environment                         -- Environment passed as parameter
        );
    END LOOP;
END;
$$;


ALTER FUNCTION "test"."bulk_add_played_track"("p_track_info" "prod"."add_played_track_type"[], "p_user_id" "uuid", "p_environment" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "test"."clear_test_tables"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Disable foreign key checks to avoid dependency issues during truncation
    SET session_replication_role = 'replica';

    -- Truncate all test schema tables
    TRUNCATE TABLE
        test.albums,
        test.track_albums,
        test.tracks,
        test.played_tracks
    RESTART IDENTITY;  -- Resets the sequences (IDs)

    -- Re-enable foreign key checks
    SET session_replication_role = 'origin';

    RAISE NOTICE 'Test schema tables have been cleared.';
END;
$$;


ALTER FUNCTION "test"."clear_test_tables"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "prod"."albums" (
    "album_id" bigint NOT NULL,
    "album_name" "text",
    "album_type" "text",
    "num_tracks" integer,
    "release_date" "date",
    "artists" "text"[],
    "genre" "text"[],
    "upc" "text",
    "ean" "text",
    "popularity" integer,
    "image" "jsonb"
);


ALTER TABLE "prod"."albums" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "prod"."albums_album_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "prod"."albums_album_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "prod"."albums_album_id_seq" OWNED BY "prod"."albums"."album_id";



CREATE TABLE IF NOT EXISTS "prod"."played_tracks" (
    "play_id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "track_id" bigint NOT NULL,
    "listened_at" bigint NOT NULL,
    "popularity" smallint,
    "isrc" "prod"."isrc"
);


ALTER TABLE "prod"."played_tracks" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "prod"."played_tracks_play_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "prod"."played_tracks_play_id_seq" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "prod"."played_tracks_play_id_seq1"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "prod"."played_tracks_play_id_seq1" OWNER TO "postgres";


ALTER SEQUENCE "prod"."played_tracks_play_id_seq1" OWNED BY "prod"."played_tracks"."play_id";



CREATE TABLE IF NOT EXISTS "prod"."track_albums" (
    "track_id" bigint NOT NULL,
    "album_id" bigint NOT NULL
);


ALTER TABLE "prod"."track_albums" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prod"."tracks" (
    "track_id" bigint NOT NULL,
    "isrc" "prod"."isrc",
    "track_name" "text",
    "track_artists" "text"[],
    "track_duration_ms" integer
);


ALTER TABLE "prod"."tracks" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prod"."played_tracks_with_album" AS
 SELECT "pt"."play_id",
    "pt"."user_id",
    "pt"."track_id",
    "t"."track_name",
    "t"."track_artists",
    "t"."track_duration_ms",
    "pt"."listened_at",
    "pt"."popularity" AS "track_popularity",
    "pt"."isrc",
    "a"."album_id",
    "a"."album_name",
    "a"."album_type",
    "a"."num_tracks",
    "a"."release_date",
    "a"."artists" AS "album_artists",
    "a"."genre" AS "album_genre",
    "a"."popularity" AS "album_popularity",
    "a"."image"
   FROM ((("prod"."played_tracks" "pt"
     JOIN "prod"."tracks" "t" ON (("pt"."track_id" = "t"."track_id")))
     JOIN "prod"."track_albums" "ta" ON (("t"."track_id" = "ta"."track_id")))
     JOIN "prod"."albums" "a" ON (("ta"."album_id" = "a"."album_id")));


ALTER TABLE "prod"."played_tracks_with_album" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "prod"."tracks_track_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "prod"."tracks_track_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "prod"."tracks_track_id_seq" OWNED BY "prod"."tracks"."track_id";



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


CREATE TABLE IF NOT EXISTS "test"."albums" (
    "album_id" bigint DEFAULT "nextval"('"prod"."albums_album_id_seq"'::"regclass") NOT NULL,
    "album_name" "text",
    "album_type" "text",
    "num_tracks" integer,
    "release_date" "date",
    "artists" "text"[],
    "genre" "text"[],
    "upc" "text",
    "ean" "text",
    "popularity" integer,
    "image" "jsonb"
);


ALTER TABLE "test"."albums" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "test"."albums_album_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "test"."albums_album_id_seq" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "test"."played_tracks" (
    "play_id" bigint DEFAULT "nextval"('"prod"."played_tracks_play_id_seq1"'::"regclass") NOT NULL,
    "user_id" "uuid" NOT NULL,
    "track_id" bigint NOT NULL,
    "listened_at" bigint NOT NULL,
    "popularity" smallint,
    "isrc" "prod"."isrc"
);


ALTER TABLE "test"."played_tracks" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "test"."played_tracks_play_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "test"."played_tracks_play_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "test"."played_tracks_play_id_seq" OWNED BY "test"."played_tracks"."play_id";



CREATE TABLE IF NOT EXISTS "test"."track_albums" (
    "track_id" bigint NOT NULL,
    "album_id" bigint NOT NULL
);


ALTER TABLE "test"."track_albums" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "test"."tracks" (
    "track_id" bigint DEFAULT "nextval"('"prod"."tracks_track_id_seq"'::"regclass") NOT NULL,
    "isrc" "prod"."isrc",
    "track_name" "text",
    "track_artists" "text"[],
    "track_duration_ms" integer
);


ALTER TABLE "test"."tracks" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "test"."tracks_track_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "test"."tracks_track_id_seq" OWNER TO "postgres";


ALTER TABLE ONLY "prod"."albums" ALTER COLUMN "album_id" SET DEFAULT "nextval"('"prod"."albums_album_id_seq"'::"regclass");



ALTER TABLE ONLY "prod"."played_tracks" ALTER COLUMN "play_id" SET DEFAULT "nextval"('"prod"."played_tracks_play_id_seq1"'::"regclass");



ALTER TABLE ONLY "prod"."tracks" ALTER COLUMN "track_id" SET DEFAULT "nextval"('"prod"."tracks_track_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."played_tracks" ALTER COLUMN "play_id" SET DEFAULT "nextval"('"public"."played_tracks_play_id_seq"'::"regclass");



ALTER TABLE ONLY "prod"."albums"
    ADD CONSTRAINT "albums_pkey" PRIMARY KEY ("album_id");



ALTER TABLE ONLY "prod"."albums"
    ADD CONSTRAINT "noduplicates" UNIQUE NULLS NOT DISTINCT ("album_name", "album_type", "num_tracks", "release_date", "artists", "genre", "upc", "ean", "popularity", "image");



ALTER TABLE ONLY "prod"."tracks"
    ADD CONSTRAINT "noduplicates_1" UNIQUE NULLS NOT DISTINCT ("isrc", "track_name", "track_artists", "track_duration_ms");



ALTER TABLE ONLY "prod"."played_tracks"
    ADD CONSTRAINT "noduplicates_played" UNIQUE NULLS NOT DISTINCT ("user_id", "track_id", "listened_at", "popularity", "isrc");



ALTER TABLE ONLY "prod"."played_tracks"
    ADD CONSTRAINT "played_tracks_pkey" PRIMARY KEY ("play_id");



ALTER TABLE ONLY "prod"."track_albums"
    ADD CONSTRAINT "track_albums_pkey" PRIMARY KEY ("track_id", "album_id");



ALTER TABLE ONLY "prod"."tracks"
    ADD CONSTRAINT "tracks_pkey" PRIMARY KEY ("track_id");



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



ALTER TABLE ONLY "test"."albums"
    ADD CONSTRAINT "albums_album_name_album_type_num_tracks_release_date_artist_key" UNIQUE NULLS NOT DISTINCT ("album_name", "album_type", "num_tracks", "release_date", "artists", "genre", "upc", "ean", "popularity", "image");



ALTER TABLE ONLY "test"."albums"
    ADD CONSTRAINT "albums_pkey" PRIMARY KEY ("album_id");



ALTER TABLE ONLY "test"."played_tracks"
    ADD CONSTRAINT "played_tracks_pkey" PRIMARY KEY ("play_id");



ALTER TABLE ONLY "test"."played_tracks"
    ADD CONSTRAINT "played_tracks_user_id_track_id_listened_at_popularity_isrc_key" UNIQUE NULLS NOT DISTINCT ("user_id", "track_id", "listened_at", "popularity", "isrc");



ALTER TABLE ONLY "test"."track_albums"
    ADD CONSTRAINT "track_albums_pkey" PRIMARY KEY ("track_id", "album_id");



ALTER TABLE ONLY "test"."tracks"
    ADD CONSTRAINT "tracks_isrc_track_name_track_artists_track_duration_ms_key" UNIQUE NULLS NOT DISTINCT ("isrc", "track_name", "track_artists", "track_duration_ms");



ALTER TABLE ONLY "test"."tracks"
    ADD CONSTRAINT "tracks_pkey" PRIMARY KEY ("track_id");



CREATE INDEX "idx_user_id" ON "public"."played_tracks" USING "btree" ("user_id");



CREATE OR REPLACE TRIGGER "get_mbid" AFTER INSERT ON "public"."tracks" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('http://192.168.1.253:54321/functions/v1/get-musicbrainz-data', 'POST', '{"Content-type":"application/json"}', '{"isrcReq":"{     isrc,    albumName   };"}', '5000');



ALTER TABLE ONLY "prod"."track_albums"
    ADD CONSTRAINT "album_id_ref" FOREIGN KEY ("album_id") REFERENCES "prod"."albums"("album_id") ON DELETE CASCADE;



ALTER TABLE ONLY "prod"."track_albums"
    ADD CONSTRAINT "track_id_ref" FOREIGN KEY ("track_id") REFERENCES "prod"."tracks"("track_id") ON DELETE CASCADE;



ALTER TABLE ONLY "prod"."played_tracks"
    ADD CONSTRAINT "track_id_ref" FOREIGN KEY ("track_id") REFERENCES "prod"."tracks"("track_id") ON DELETE CASCADE;



ALTER TABLE ONLY "prod"."played_tracks"
    ADD CONSTRAINT "user_id_ref" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") DEFERRABLE INITIALLY DEFERRED;



ALTER TABLE ONLY "public"."played_tracks"
    ADD CONSTRAINT "fk_isrc" FOREIGN KEY ("isrc") REFERENCES "public"."tracks"("isrc");



ALTER TABLE ONLY "public"."played_tracks"
    ADD CONSTRAINT "played_tracks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."spotify_credentials"
    ADD CONSTRAINT "spotify_credentials_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "test"."track_albums"
    ADD CONSTRAINT "album_id_ref" FOREIGN KEY ("track_id") REFERENCES "test"."albums"("album_id");



ALTER TABLE ONLY "test"."track_albums"
    ADD CONSTRAINT "track_id_ref" FOREIGN KEY ("track_id") REFERENCES "test"."tracks"("track_id");



ALTER TABLE ONLY "test"."played_tracks"
    ADD CONSTRAINT "track_id_ref" FOREIGN KEY ("track_id") REFERENCES "test"."tracks"("track_id");



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



CREATE PUBLICATION "logflare_pub" WITH (publish = 'insert, update, delete, truncate');


ALTER PUBLICATION "logflare_pub" OWNER TO "supabase_admin";




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";





GRANT ALL ON SCHEMA "prod" TO PUBLIC;
GRANT USAGE ON SCHEMA "prod" TO "anon";
GRANT USAGE ON SCHEMA "prod" TO "authenticated";
GRANT USAGE ON SCHEMA "prod" TO "service_role";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON SCHEMA "test" TO PUBLIC;
GRANT USAGE ON SCHEMA "test" TO "anon";
GRANT USAGE ON SCHEMA "test" TO "authenticated";
GRANT USAGE ON SCHEMA "test" TO "service_role";

GRANT ALL ON FUNCTION "public"."add_played_track"("p_isrc" "public"."isrc", "p_popularity" smallint, "p_track_album" "public"."album", "p_track_artists" "text"[], "p_track_duration_ms" integer, "p_track_name" "text", "p_user_id" "uuid", "p_listened_at" timestamp without time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."add_played_track"("p_isrc" "public"."isrc", "p_popularity" smallint, "p_track_album" "public"."album", "p_track_artists" "text"[], "p_track_duration_ms" integer, "p_track_name" "text", "p_user_id" "uuid", "p_listened_at" timestamp without time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_played_track"("p_isrc" "public"."isrc", "p_popularity" smallint, "p_track_album" "public"."album", "p_track_artists" "text"[], "p_track_duration_ms" integer, "p_track_name" "text", "p_user_id" "uuid", "p_listened_at" timestamp without time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."clear_test_tables"() TO "anon";
GRANT ALL ON FUNCTION "public"."clear_test_tables"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."clear_test_tables"() TO "service_role";



GRANT ALL ON FUNCTION "public"."duplicate_view"("src_schema" "text", "dest_schema" "text", "view_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."duplicate_view"("src_schema" "text", "dest_schema" "text", "view_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."duplicate_view"("src_schema" "text", "dest_schema" "text", "view_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."format_music_request"("isrc" "text", "album_name" "text", "upc" "text", "ean" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."format_music_request"("isrc" "text", "album_name" "text", "upc" "text", "ean" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."format_music_request"("isrc" "text", "album_name" "text", "upc" "text", "ean" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "test"."add_played_track"("p_track_json" "jsonb", "p_album_json" "prod"."album_type", "p_listened_at" timestamp with time zone, "p_user_id" "uuid", "p_environment" "text") TO "anon";
GRANT ALL ON FUNCTION "test"."add_played_track"("p_track_json" "jsonb", "p_album_json" "prod"."album_type", "p_listened_at" timestamp with time zone, "p_user_id" "uuid", "p_environment" "text") TO "authenticated";
GRANT ALL ON FUNCTION "test"."add_played_track"("p_track_json" "jsonb", "p_album_json" "prod"."album_type", "p_listened_at" timestamp with time zone, "p_user_id" "uuid", "p_environment" "text") TO "service_role";



GRANT ALL ON FUNCTION "test"."bulk_add_played_track"("p_track_info" "prod"."add_played_track_type"[], "p_user_id" "uuid", "p_environment" "text") TO "anon";
GRANT ALL ON FUNCTION "test"."bulk_add_played_track"("p_track_info" "prod"."add_played_track_type"[], "p_user_id" "uuid", "p_environment" "text") TO "authenticated";
GRANT ALL ON FUNCTION "test"."bulk_add_played_track"("p_track_info" "prod"."add_played_track_type"[], "p_user_id" "uuid", "p_environment" "text") TO "service_role";



GRANT ALL ON FUNCTION "test"."clear_test_tables"() TO "anon";
GRANT ALL ON FUNCTION "test"."clear_test_tables"() TO "authenticated";
GRANT ALL ON FUNCTION "test"."clear_test_tables"() TO "service_role";


















GRANT ALL ON TABLE "prod"."albums" TO "anon";
GRANT ALL ON TABLE "prod"."albums" TO "authenticated";
GRANT ALL ON TABLE "prod"."albums" TO "service_role";



GRANT ALL ON SEQUENCE "prod"."albums_album_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "prod"."albums_album_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "prod"."albums_album_id_seq" TO "service_role";



GRANT ALL ON TABLE "prod"."played_tracks" TO "anon";
GRANT ALL ON TABLE "prod"."played_tracks" TO "authenticated";
GRANT ALL ON TABLE "prod"."played_tracks" TO "service_role";



GRANT ALL ON SEQUENCE "prod"."played_tracks_play_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "prod"."played_tracks_play_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "prod"."played_tracks_play_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "prod"."played_tracks_play_id_seq1" TO "anon";
GRANT ALL ON SEQUENCE "prod"."played_tracks_play_id_seq1" TO "authenticated";
GRANT ALL ON SEQUENCE "prod"."played_tracks_play_id_seq1" TO "service_role";



GRANT ALL ON TABLE "prod"."track_albums" TO "anon";
GRANT ALL ON TABLE "prod"."track_albums" TO "authenticated";
GRANT ALL ON TABLE "prod"."track_albums" TO "service_role";



GRANT ALL ON TABLE "prod"."tracks" TO "anon";
GRANT ALL ON TABLE "prod"."tracks" TO "authenticated";
GRANT ALL ON TABLE "prod"."tracks" TO "service_role";



GRANT ALL ON TABLE "prod"."played_tracks_with_album" TO "anon";
GRANT ALL ON TABLE "prod"."played_tracks_with_album" TO "authenticated";
GRANT ALL ON TABLE "prod"."played_tracks_with_album" TO "service_role";



GRANT ALL ON SEQUENCE "prod"."tracks_track_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "prod"."tracks_track_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "prod"."tracks_track_id_seq" TO "service_role";



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
GRANT SELECT ON TABLE "public"."spotify_credentials" TO PUBLIC;



GRANT ALL ON TABLE "public"."tracks" TO "anon";
GRANT ALL ON TABLE "public"."tracks" TO "authenticated";
GRANT ALL ON TABLE "public"."tracks" TO "service_role";



GRANT ALL ON TABLE "public"."track_play_details" TO "anon";
GRANT ALL ON TABLE "public"."track_play_details" TO "authenticated";
GRANT ALL ON TABLE "public"."track_play_details" TO "service_role";



GRANT ALL ON TABLE "test"."albums" TO "anon";
GRANT ALL ON TABLE "test"."albums" TO "authenticated";
GRANT ALL ON TABLE "test"."albums" TO "service_role";



GRANT ALL ON SEQUENCE "test"."albums_album_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "test"."albums_album_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "test"."albums_album_id_seq" TO "service_role";



GRANT ALL ON TABLE "test"."played_tracks" TO "anon";
GRANT ALL ON TABLE "test"."played_tracks" TO "authenticated";
GRANT ALL ON TABLE "test"."played_tracks" TO "service_role";



GRANT ALL ON SEQUENCE "test"."played_tracks_play_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "test"."played_tracks_play_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "test"."played_tracks_play_id_seq" TO "service_role";



GRANT ALL ON TABLE "test"."track_albums" TO "anon";
GRANT ALL ON TABLE "test"."track_albums" TO "authenticated";
GRANT ALL ON TABLE "test"."track_albums" TO "service_role";



GRANT ALL ON TABLE "test"."tracks" TO "anon";
GRANT ALL ON TABLE "test"."tracks" TO "authenticated";
GRANT ALL ON TABLE "test"."tracks" TO "service_role";



GRANT ALL ON SEQUENCE "test"."tracks_track_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "test"."tracks_track_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "test"."tracks_track_id_seq" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "prod" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "prod" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "prod" GRANT ALL ON SEQUENCES  TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "prod" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "prod" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "prod" GRANT ALL ON FUNCTIONS  TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "prod" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "prod" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "prod" GRANT ALL ON TABLES  TO "service_role";



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






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "test" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "test" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "test" GRANT ALL ON SEQUENCES  TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "test" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "test" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "test" GRANT ALL ON FUNCTIONS  TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "test" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "test" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "test" GRANT ALL ON TABLES  TO "service_role";

RESET ALL;
