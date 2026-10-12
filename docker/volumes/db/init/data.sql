CREATE SCHEMA IF NOT EXISTS public;
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

CREATE EXTENSION postgres_fdw;

CREATE SERVER musicbrainz
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host '100.78.99.13', dbname 'musicbrainz_db', port '5432');

CREATE USER MAPPING FOR postgres
SERVER musicbrainz
OPTIONS (user 'musicbrainz', password 'musicbrainz');

CREATE FOREIGN TABLE public.release (
    id            integer                  NOT NULL,
    gid           uuid                     NOT NULL,
    name          varchar                  NOT NULL,
    artist_credit integer                  NOT NULL,
    release_group integer                  NOT NULL,
    status        integer,
    packaging     integer,
    language      integer,
    script        integer,
    barcode       varchar(255),
    comment       varchar(255)             NOT NULL,
    edits_pending integer                  NOT NULL,
    quality       smallint                 NOT NULL,
    last_updated  timestamp with time zone
)
SERVER musicbrainz
OPTIONS (schema_name 'musicbrainz', table_name 'release');

create foreign table public.release_group
(
    id            integer not null,
    gid           uuid                                                   not null,
    name          varchar                                                not null,
    artist_credit integer                                                not null,
    type          integer,
    comment       varchar(255)             default ''::character varying not null,
    edits_pending integer                                       not null,
    last_updated  timestamp with time zone
)
SERVER musicbrainz
OPTIONS (schema_name 'musicbrainz', table_name 'release_group');

create foreign table recording
(
    id           integer not null,
    gid           uuid                                                   not null,
    name          varchar                                                not null,
    artist_credit integer                                                not null,
    length        integer not null,
    comment       varchar(255)             default ''::character varying not null,
    edits_pending integer                  default 0                     not null,
    last_updated  timestamp with time zone,
    video         boolean                  default false                 not null
)
SERVER musicbrainz
OPTIONS (schema_name 'musicbrainz', table_name 'release_group');

-- Albums
CREATE TABLE IF NOT EXISTS public.albums (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_title text NOT NULL,
    source_artists text[] NOT NULL,
    source_album_type text NOT NULL,
    source_image text NOT NULL,
    source_service text NOT NULL,
    source_external_id text NOT NULL,
    source_data jsonb,
    UNIQUE NULLS NOT DISTINCT (
        source_service, source_artists, source_external_id, source_title
    )

);

ALTER TABLE public.albums OWNER TO "postgres";
ALTER TABLE public.albums ENABLE ROW LEVEL SECURITY;

-- Tracks
CREATE TABLE IF NOT EXISTS public.tracks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    album_id uuid REFERENCES public.albums(id) ON DELETE CASCADE,
    source_title text NOT NULL,
    source_artists text[] NOT NULL,
    source_service text NOT NULL,
    source_external_id text NOT NULL,
    UNIQUE NULLS NOT DISTINCT (
        album_id, source_service, source_artists, source_external_id, source_title
    )
);

ALTER TABLE public.tracks OWNER TO "postgres";
ALTER TABLE public.tracks ENABLE ROW LEVEL SECURITY;

-- Played tracks
CREATE TABLE IF NOT EXISTS public.plays (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  track_id uuid REFERENCES public.tracks(id) ON DELETE CASCADE,
  timestamp bigint NOT NULL,
  track_popularity smallint,
  album_popularity smallint,
  UNIQUE NULLS NOT DISTINCT (user_id,track_id, timestamp)
);

ALTER TABLE public.plays OWNER TO "postgres";
ALTER TABLE public.plays ENABLE ROW LEVEL SECURITY;


-- Album -> MusicBrainz release
CREATE TABLE IF NOT EXISTS public.mb_album_releases(
    release_id uuid NOT NULL,
    album_id uuid NOT NULL REFERENCES public.albums(id) ON DELETE CASCADE,
    release_group_id uuid NOT NULL,
    is_primary boolean NOT NULL DEFAULT false,
    UNIQUE (release_id, album_id),
    created_at timestamptz NOT NULL,
    updated_at timestamptz
);

ALTER TABLE public.mb_album_releases OWNER TO "postgres";
ALTER TABLE public.mb_album_releases ENABLE ROW LEVEL SECURITY;

-- Track -> MusicBrainz recording
create table public.mb_track_recordings(
    recording_id uuid NOT null,
    track_id uuid NOT NULL REFERENCES public.tracks(id) ON DELETE CASCADE,
    release_id uuid,
    is_primary boolean NOT NULL DEFAULT false,
    UNIQUE (recording_id, track_id),
    created_at timestamptz NOT NULL,
    updated_at timestamptz
);

ALTER TABLE public.mb_track_recordings OWNER TO "postgres";
ALTER TABLE public.mb_track_recordings ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.mb_album_art(
    release_id uuid NOT NULL,
    image_type text NOT NULL,
    image_url text NOT NULL,
    PRIMARY KEY (release_id, image_type)
);

-- Profiles
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    updated_at timestamptz NOT NULL,
    username text NOT NULL,
    name text,
    theme text NOT NULL,
    avatar_id text
);

ALTER TABLE public.profiles OWNER TO "postgres";
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Connected accounts
CREATE TABLE IF NOT EXISTS public.connected_accounts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    provider text NOT NULL,
    refresh_token text,
    access_token text,
    access_token_expires_at timestamptz,
    scope text NOT NULL,
    UNIQUE (user_id, provider),
    CHECK (provider IN ('spotify', 'apple'))
);

ALTER TABLE public.connected_accounts OWNER TO "postgres";
ALTER TABLE public.connected_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "only service insert albums"
ON public.albums
FOR INSERT
TO service_role
WITH CHECK (true);

CREATE POLICY "only service insert plays"
ON public.plays
FOR INSERT
TO service_role
WITH CHECK (true);

CREATE POLICY "only service insert tracks"
ON public.tracks
FOR INSERT
TO service_role
WITH CHECK (true);

CREATE POLICY "authenticated users can manage connected accounts"
ON public.connected_accounts
FOR ALL
TO authenticated
USING ( (select auth.uid()) = user_id );

CREATE POLICY "authenticated users can manage profiles"
ON public.profiles
FOR ALL
TO authenticated
USING ( (select auth.uid()) = id );
