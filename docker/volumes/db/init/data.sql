-- CREATE SCHEMA public; --this may be needed if you have errors relating to public check here
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

CREATE SCHEMA IF NOT EXISTS prod;

-- Grant permissions on the prod schema
GRANT USAGE ON SCHEMA prod TO public;
GRANT CREATE ON SCHEMA prod TO public;

-- Grant permissions on the test schema

-- Grant object-level permissions for tables in prod schema
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA prod TO public;

-- Grant object-level permissions for tables in test schema
CREATE DOMAIN "prod"."isrc" AS "text" NOT NULL
	CONSTRAINT "isrc_check" CHECK ((VALUE ~* '^[A-Za-z]{2}-?\w{3}-?\d{2}-?\d{5}$'::"text"));
ALTER DOMAIN "prod"."isrc" OWNER TO "postgres";


-- Albums
CREATE TABLE IF NOT EXISTS "prod"."albums"(
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "name" text NOT NULL,
    "type" text NOT NULL,
    "num_tracks" int NOT NULL,
    "release_day" smallint,
    "release_month" smallint,
    "release_year" smallint,
    "artists" text[] NOT NULL,
    "genre" text[],
    "upc" text,
    "ean" text,
    "external_id" text NOT NULL,
	"image_small" text,
	"image_large" text,
    "num_dics" int,
    CONSTRAINT noduplicates UNIQUE NULLS NOT DISTINCT ("name", "type", "num_tracks", "release_day", "release_month", "release_year", "artists", "genre")
);


ALTER TABLE "prod"."albums" OWNER TO "postgres";

-- Tracks
CREATE TABLE prod.tracks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    isrc prod.isrc,
    name text,
    artists text[],
    duration_ms integer,
    external_id text,
    album_id uuid,
    track_num int,
    source text NOT NULL,
    CONSTRAINT album_id_ref
        FOREIGN KEY (album_id)
        REFERENCES prod.albums(id)
        ON DELETE CASCADE,
    CONSTRAINT noduplicates_1
        UNIQUE NULLS NOT DISTINCT (isrc, name, artists, duration_ms)
);

--CREATE UNIQUE INDEX idx_unique_albums
--ON "prod"."albums" (album_name, album_type, num_tracks, release_day,release_month,release_year, artists, genre, upc, ean, popularity, image);

ALTER TABLE "prod"."tracks" OWNER TO "postgres";

/* ============================================================
   MUSICBRAINZ CANONICAL TABLES (DERIVED VIA LIKE)
   ============================================================ */
   /* -----------------------
      MB RELEASE GROUPS
      ----------------------- */
CREATE TABLE IF NOT EXISTS prod.mb_release_groups (
    LIKE prod.albums INCLUDING DEFAULTS
);

ALTER TABLE prod.mb_release_groups
    DROP COLUMN id,
    DROP COLUMN external_id,
    DROP COLUMN upc,
    DROP COLUMN ean,
    ADD COLUMN id uuid PRIMARY KEY, --this represents an mbid
    ADD COLUMN primary_type text,
    ADD COLUMN secondary_types text[],
    ADD COLUMN created_at bigint NOT NULL,
    ADD COLUMN updated_at bigint NOT NULL;

ALTER TABLE prod.mb_release_groups OWNER TO postgres;

GRANT ALL ON TABLE prod.mb_release_groups TO anon, authenticated, service_role;


   /* -----------------------
      MB RELEASES
      ----------------------- */
CREATE TABLE IF NOT EXISTS prod.mb_releases (
    LIKE prod.albums INCLUDING DEFAULTS
);

ALTER TABLE prod.mb_releases
    DROP COLUMN id,
    DROP COLUMN external_id,
    ADD COLUMN id uuid PRIMARY KEY,
    ADD COLUMN release_group_mbid uuid,
    ADD COLUMN status text,
    ADD COLUMN created_at bigint NOT NULL,
    ADD COLUMN updated_at bigint NOT NULL;

ALTER TABLE prod.mb_releases OWNER TO postgres;

ALTER TABLE prod.mb_releases
    ADD CONSTRAINT release_group_mbid_ref FOREIGN KEY ("release_group_mbid")
    references "prod".mb_release_groups("id");

GRANT ALL ON TABLE prod.mb_releases TO anon, authenticated, service_role;

/* -----------------------
   MB RECORDINGS
   ----------------------- */
CREATE TABLE IF NOT EXISTS prod.mb_recordings (
  LIKE prod.tracks INCLUDING DEFAULTS
);

ALTER TABLE prod.mb_recordings
  DROP COLUMN id,
  DROP COLUMN album_id,
  DROP COLUMN external_id,
  ADD COLUMN id uuid PRIMARY KEY,
  ADD COLUMN release_mbid uuid,
  ADD COLUMN first_release_year smallint,
  ADD COLUMN created_at bigint NOT NULL,
  ADD COLUMN updated_at bigint NOT NULL;

ALTER TABLE prod.mb_recordings
    ADD CONSTRAINT release_mbid_ref FOREIGN KEY ("release_mbid")
    references "prod".mb_releases("id");

ALTER TABLE prod.mb_recordings OWNER TO postgres;

GRANT ALL ON TABLE prod.mb_recordings TO anon, authenticated, service_role;


/* ============================================================
   PLAYED TRACKS = GLUE POINT
   ============================================================ */


-- Played Tracks
create table prod.played_tracks (
  id uuid primary key DEFAULT gen_random_uuid(),
  user_id uuid not null,
  track_id uuid not null,
  listened_at  bigint  not null ,
  track_popularity smallint,
  album_popularity smallint,
  album_popularity_updated_at bigint,
  selected_mbid uuid,
  CONSTRAINT mbid_ref foreign key ("selected_mbid") references "prod"."mb_recordings"("id") on delete cascade,
  Constraint track_id_ref FOREIGN KEY ("id") REFERENCES "prod"."tracks"("track_id") ON DELETE CASCADE,
  Constraint user_id_ref FOREIGN KEY ("user_id") References "auth".users(id) on delete cascade,
  CONSTRAINT noduplicates_played UNIQUE NULLS NOT DISTINCT (user_id,track_id,listened_at)
);

CREATE TABLE prod.unmatched_played_tracks (LIKE prod.played_tracks INCLUDING ALL);
ALTER TABLE prod.unmatched_played_tracks ADD CONSTRAINT track_id_ref FOREIGN KEY (track_id) REFERENCES prod.tracks("track_id");
alter table prod.unmatched_played_tracks add Constraint user_id_ref_test FOREIGN KEY ("user_id") References "auth".users(id) on delete cascade;


/* ============================================================
   INDEXES (OPTIONAL BUT RECOMMENDED)
   ============================================================ */

CREATE INDEX IF NOT EXISTS idx_mb_recordings_isrc
  ON prod.mb_recordings (isrc);

CREATE INDEX IF NOT EXISTS idx_played_tracks_user_track
  ON prod.played_tracks (user_id, track_id);

CREATE INDEX IF NOT EXISTS idx_played_tracks_recording
  ON prod.played_tracks (selected_mbid);


GRANT USAGE ON SCHEMA prod TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA prod TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA prod TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA prod TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA prod GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA prod GRANT ALL ON ROUTINES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA prod GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

-- might not need this if we have the above
ALTER table "prod"."albums" OWNER TO "postgres";

GRANT ALL ON TABLE "prod"."albums" TO "anon";
GRANT ALL ON TABLE "prod"."albums" TO "authenticated";
GRANT ALL ON TABLE "prod"."albums" TO "service_role";

GRANT ALL ON TABLE "prod"."played_tracks" TO "anon";
GRANT ALL ON TABLE "prod"."played_tracks" TO "authenticated";
GRANT ALL ON TABLE "prod"."played_tracks" TO "service_role";

GRANT ALL ON TABLE "prod"."unmatched_played_tracks" TO "anon";
GRANT ALL ON TABLE "prod"."unmatched_played_tracks" TO "authenticated";
GRANT ALL ON TABLE "prod"."unmatched_played_tracks" TO "service_role";

GRANT USAGE ON SCHEMA prod TO anon, authenticated, service_role;

GRANT ALL ON ALL TABLES IN SCHEMA prod
  TO anon, authenticated, service_role;

GRANT ALL ON ALL ROUTINES IN SCHEMA prod
  TO anon, authenticated, service_role;

GRANT ALL ON ALL SEQUENCES IN SCHEMA prod
  TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA prod
  GRANT ALL ON TABLES TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA prod
  GRANT ALL ON ROUTINES TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA prod
  GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

-- Profiles
CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL PRIMARY KEY,
    "updated_at" timestamp with time zone,
    "username" "text",
    "full_name" "text",
    "avatar_url" "text",
    "website" "text",
    "theme" "text",
    CONSTRAINT "username_length" CHECK (("char_length"("username") >= 3))
);

ALTER TABLE "public"."profiles" OWNER TO "postgres";

GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";

ALTER TABLE ONLY "public"."profiles"
ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

-- Spotify credentials


CREATE TABLE IF NOT EXISTS "public"."spotify_credentials" (
    "id" "uuid" PRIMARY KEY NOT NULL references "auth"."users"("id") ON DELETE CASCADE,
    "refresh_token" "text"
);


ALTER TABLE "public"."spotify_credentials" OWNER TO "postgres";

GRANT ALL ON TABLE "public"."spotify_credentials" TO "anon";
GRANT ALL ON TABLE "public"."spotify_credentials" TO "authenticated";
GRANT ALL ON TABLE "public"."spotify_credentials" TO "service_role";
