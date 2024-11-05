-- CREATE SCHEMA public; --this may be needed if you have errors relating to public check here
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

CREATE SCHEMA IF NOT EXISTS test;
CREATE SCHEMA IF NOT EXISTS prod;

-- Grant permissions on the prod schema
GRANT USAGE ON SCHEMA prod TO public;
GRANT CREATE ON SCHEMA prod TO public;

-- Grant permissions on the test schema
GRANT USAGE ON SCHEMA test TO public;
GRANT CREATE ON SCHEMA test TO public;

-- Grant object-level permissions for tables in prod schema
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA prod TO public;

-- Grant object-level permissions for tables in test schema
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA test TO public;
CREATE DOMAIN "prod"."isrc" AS "text" NOT NULL
	CONSTRAINT "isrc_check" CHECK ((VALUE ~* '^[A-Za-z]{2}-?\w{3}-?\d{2}-?\d{5}$'::"text"));
ALTER DOMAIN "prod"."isrc" OWNER TO "postgres";

-- Albums
CREATE TABLE IF NOT EXISTS "prod"."albums"(
    "album_id" BIGSERIAL PRIMARY KEY,
    "album_name" text,
    "album_type" text,
    "num_tracks" int,
    "release_date" date,
    "artists" text[],
    "genre" text[],
    "upc" text,
    "ean" text,
    "popularity" int,
    "image" jsonb,
    CONSTRAINT noduplicates UNIQUE NULLS NOT DISTINCT (album_name, album_type, num_tracks, release_date, artists, genre, upc, ean, popularity, image)
);

CREATE TABLE test.albums (LIKE prod.albums INCLUDING ALL);
ALTER TABLE ONLY test.albums add constraint "nodups_test" UNIQUE NULLS NOT DISTINCT (album_name, album_type, num_tracks, release_date, artists, genre, upc, ean, popularity, image);

ALTER TABLE "prod"."albums" OWNER TO "postgres";
ALTER TABLE "test"."albums" OWNER TO "postgres";

-- Tracks
CREATE TABLE IF NOT EXISTS prod."tracks" (
    track_id BIGSERIAL primary key,
    "isrc" "prod"."isrc",
    "track_name" "text",
    "track_artists" "text"[],
    "track_duration_ms" integer,
    CONSTRAINT noduplicates_1 UNIQUE NULLS NOT DISTINCT ("isrc", "track_name", "track_artists", "track_duration_ms")
);
CREATE TABLE test.tracks (LIKE prod.tracks INCLUDING ALL);

CREATE TABLE IF NOT EXISTS "prod"."track_albums" (
    "track_id" bigint,
    "album_id" bigint,
    PRIMARY KEY ("track_id", "album_id"),
    constraint track_id_ref FOREIGN KEY ("track_id") REFERENCES "prod"."tracks"("track_id") ON DELETE CASCADE,
    constraint album_id_ref FOREIGN KEY ("album_id") REFERENCES "prod"."albums"("album_id") ON DELETE CASCADE
);

CREATE UNIQUE INDEX idx_unique_albums
ON "prod"."albums" (album_name, album_type, num_tracks, release_date, artists, genre, upc, ean, popularity, image);

CREATE TABLE test.track_albums (LIKE prod.track_albums INCLUDING ALL);
ALTER TABLE test.track_albums ADD CONSTRAINT track_id_ref FOREIGN KEY (track_id) REFERENCES test.tracks("track_id");
ALTER TABLE test.track_albums ADD CONSTRAINT album_id_ref FOREIGN KEY (track_id) REFERENCES test.albums("album_id");

ALTER table "prod"."track_albums" OWNER TO "postgres";
ALTER table test.track_albums OWNER TO "postgres";

ALTER TABLE "prod"."tracks" OWNER TO "postgres";
ALTER TABLE "test"."tracks" OWNER TO "postgres";

-- Played Tracks
create table prod.played_tracks (
  play_id BIGSERIAL primary key not null,
  user_id uuid not null,
  track_id bigint not null,
  listened_at  bigint  not null ,
  popularity smallint,
  isrc prod.isrc,
  Constraint track_id_ref FOREIGN KEY ("track_id") REFERENCES "prod"."tracks"("track_id") ON DELETE CASCADE,
  Constraint user_id_ref FOREIGN KEY ("user_id") References "auth".users(id) on delete no action initially deferred,
  CONSTRAINT noduplicates_played UNIQUE NULLS NOT DISTINCT (user_id,track_id,listened_at,popularity,isrc)
);
CREATE table test.played_tracks (LIKE prod.played_tracks INCLUDING ALL);
ALTER TABLE test.played_tracks ADD CONSTRAINT track_id_ref FOREIGN KEY (track_id) REFERENCES test.tracks("track_id");

-- Table permissions for test & prod
GRANT USAGE ON SCHEMA test TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA test TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA test TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA test TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA test GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA test GRANT ALL ON ROUTINES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA test GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

GRANT USAGE ON SCHEMA prod TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA prod TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA prod TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA prod TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA prod GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA prod GRANT ALL ON ROUTINES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA prod GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

-- might not need this if we have the above
ALTER table "prod"."albums" OWNER TO "postgres";
ALTER table "test"."albums" OWNER TO "postgres";

GRANT ALL ON TABLE "prod"."albums" TO "anon";
GRANT ALL ON TABLE "prod"."albums" TO "authenticated";
GRANT ALL ON TABLE "prod"."albums" TO "service_role";

GRANT ALL ON TABLE "prod"."played_tracks" TO "anon";
GRANT ALL ON TABLE "prod"."played_tracks" TO "authenticated";
GRANT ALL ON TABLE "prod"."played_tracks" TO "service_role";

GRANT ALL ON TABLE "prod"."track_albums" TO "anon";
GRANT ALL ON TABLE "prod"."track_albums" TO "authenticated";
GRANT ALL ON TABLE "prod"."track_albums" TO "service_role";

GRANT ALL ON TABLE "prod"."tracks" TO "anon";
GRANT ALL ON TABLE "prod"."tracks" TO "authenticated";
GRANT ALL ON TABLE "prod"."tracks" TO "service_role";

GRANT ALL ON TABLE "test"."tracks" TO "anon";
GRANT ALL ON TABLE "test"."tracks" TO "authenticated";
GRANT ALL ON TABLE "test"."tracks" TO "service_role";

GRANT ALL ON TABLE "test"."albums" TO "anon";
GRANT ALL ON TABLE "test"."albums" TO "authenticated";
GRANT ALL ON TABLE "test"."albums" TO "service_role";

GRANT ALL ON TABLE "test"."played_tracks" TO "anon";
GRANT ALL ON TABLE "test"."played_tracks" TO "authenticated";
GRANT ALL ON TABLE "test"."played_tracks" TO "service_role";

GRANT ALL ON TABLE "test"."track_albums" TO "anon";
GRANT ALL ON TABLE "test"."track_albums" TO "authenticated";
GRANT ALL ON TABLE "test"."track_albums" TO "service_role";

-- continue albums here for now focus on creds

-- Profiles
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

GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";

ALTER TABLE ONLY "public"."profiles"
ADD CONSTRAINT "profiles_id_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."profiles"
ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

-- Spotify credentials

CREATE TABLE IF NOT EXISTS "public"."spotify_credentials" (
    "id" "uuid" NOT NULL references "auth"."users"("id") ON DELETE CASCADE,
    "refresh_token" "text"
);


ALTER TABLE "public"."spotify_credentials" OWNER TO "postgres";

GRANT ALL ON TABLE "public"."spotify_credentials" TO "anon";
GRANT ALL ON TABLE "public"."spotify_credentials" TO "authenticated";
GRANT ALL ON TABLE "public"."spotify_credentials" TO "service_role";

ALTER TABLE ONLY "public"."spotify_credentials"
ADD CONSTRAINT "spotify_credentials_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;