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
    "album_id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "album_name" text,
    "album_type" text,
    "num_tracks" int,
    "release_day" smallint,
    "release_month" smallint,
    "release_year" smallint,
    "artists" text[],
    "genre" text[],
    "upc" text,
    "ean" text,
    "image" text,
    "spotify_id" text,
    "num_dics" int,
    CONSTRAINT noduplicates UNIQUE NULLS NOT DISTINCT (album_name, album_type, num_tracks, release_day,release_month, release_year, artists, genre)
);


ALTER TABLE "prod"."albums" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prod"."album_mbids" (
	"album_id" uuid NOT NULL,
	"mbid" uuid unique NOT null,
	"updated_at" bigint NOT NULL,
	"score" SMALLINT,
    "type" text not null,
	CONSTRAINT album_mbid_key FOREIGN KEY ("album_id") REFERENCES "prod"."albums"("album_id") ON DELETE CASCADE
);


ALTER TABLE "prod"."album_mbids" OWNER TO "postgres";


-- Tracks
CREATE TABLE IF NOT EXISTS prod."tracks" (
    track_id uuid primary key DEFAULT gen_random_uuid(),
    "isrc" "prod"."isrc",
    "track_name" "text",
    track_artists text[],
    track_duration_ms integer,
    spotify_id text,
    album_id uuid,
    track_num int,
    --disc_num int,
    constraint album_id_ref FOREIGN KEY ("album_id") REFERENCES "prod"."albums"("album_id") ON DELETE CASCADE,
    CONSTRAINT noduplicates_1 UNIQUE NULLS NOT DISTINCT ("isrc", "track_name", "track_artists", "track_duration_ms")
);

--CREATE UNIQUE INDEX idx_unique_albums
--ON "prod"."albums" (album_name, album_type, num_tracks, release_day,release_month,release_year, artists, genre, upc, ean, popularity, image);

ALTER TABLE "prod"."tracks" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "prod"."track_mbids" (
	"track_id" uuid NOT NULL,
	"mbid" uuid unique not null,
	"updated_at" bigint NOT NULL,
	"score" SMALLINT,
	"album_mbid" uuid NOT NULL,
    "type" text NOT NULL,
	CONSTRAINT track_mbid_key FOREIGN KEY ("track_id") REFERENCES "prod"."tracks"("track_id") ON DELETE CASCADE,
	CONSTRAINT track_album_mbid_key FOREIGN KEY ("album_mbid") REFERENCES "prod"."album_mbids"("mbid") ON DELETE CASCADE
 );

create table if not exists "prod"."album_art" (
	"mbid" uuid not null,
	"small" text,
	"large" text,
	"1200" text,
	"500" text,
	"250" text,
	"source" text not null,
	"type" text not null,
	constraint mbid_ref foreign key ("mbid") references "prod".album_mbids("mbid") on delete cascade
);

-- Played Tracks
create table prod.played_tracks (
  play_id uuid primary key DEFAULT gen_random_uuid(),
  user_id uuid not null,
  track_id uuid not null,
  listened_at  bigint  not null ,
  track_popularity smallint,
  album_popularity smallint,
  album_popularity_updated_at bigint,
  isrc prod.isrc,
  selected_mbid uuid,
  CONSTRAINT mbid_ref foreign key ("selected_mbid") references "prod"."album_mbids"("mbid") on delete cascade,
  Constraint track_id_ref FOREIGN KEY ("track_id") REFERENCES "prod"."tracks"("track_id") ON DELETE CASCADE,
  Constraint user_id_ref FOREIGN KEY ("user_id") References "auth".users(id) on delete cascade,
  CONSTRAINT noduplicates_played UNIQUE NULLS NOT DISTINCT (user_id,track_id,listened_at,isrc)
);

CREATE TABLE prod.unmatched_played_tracks (LIKE prod.played_tracks INCLUDING ALL);
ALTER TABLE prod.unmatched_played_tracks ADD CONSTRAINT track_id_ref FOREIGN KEY (track_id) REFERENCES prod.tracks("track_id");
alter table prod.unmatched_played_tracks add Constraint user_id_ref_test FOREIGN KEY ("user_id") References "auth".users(id) on delete cascade;

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

-- Profiles
CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
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

-- Connected accounts
CREATE TABLE IF NOT EXISTS public.connected_accounts (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    provider text NOT NULL,
    refresh_token text NOT NULL,
    access_token text,
    access_token_expires_at timestamptz,
    scope text NOT NULL,
    UNIQUE (user_id, provider)
);

ALTER TABLE public.connected_accounts OWNER TO "postgres";
ALTER TABLE public.connected_accounts ENABLE ROW LEVEL SECURITY;

GRANT ALL ON TABLE public.connected_accounts TO "anon";
GRANT ALL ON TABLE public.connected_accounts TO "authenticated";
GRANT ALL ON TABLE public.connected_accounts TO "service_role";
