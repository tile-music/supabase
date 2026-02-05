CREATE SCHEMA IF NOT EXISTS public;
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

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

-- Track -> MusicBrainz recording
create table public.mb_track_recordings(
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    track_id uuid NOT NULL REFERENCES public.tracks(id) ON DELETE CASCADE,
    recording_id uuid NOT NULL,
    is_primary boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL,
    updated_at timestamptz
);

ALTER TABLE public.mb_track_recordings OWNER TO "postgres";
ALTER TABLE public.mb_track_recordings ENABLE ROW LEVEL SECURITY;

-- Album -> MusicBrainz release
CREATE TABLE IF NOT EXISTS public.mb_album_releases(
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    album_id uuid NOT NULL REFERENCES public.albums(id) ON DELETE CASCADE,
    recording_id uuid NOT NULL,
    is_primary boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL,
    updated_at timestamptz
);

ALTER TABLE public.mb_album_releases OWNER TO "postgres";
ALTER TABLE public.mb_album_releases ENABLE ROW LEVEL SECURITY;

-- Profiles
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    updated_at timestamptz,
    name text,
    theme text,
    avatar_id text
);

ALTER TABLE public.profiles OWNER TO "postgres";
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Connected accounts
CREATE TABLE IF NOT EXISTS public.connected_accounts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    provider text NOT NULL,
    refresh_token text NOT NULL,
    access_token text,
    access_token_expires_at timestamptz,
    scope text NOT NULL,
    UNIQUE (user_id, provider),
    CHECK (provider IN ('spotify'))
);

ALTER TABLE public.connected_accounts OWNER TO "postgres";
ALTER TABLE public.connected_accounts ENABLE ROW LEVEL SECURITY;

-- GRANT ALL ON TABLE public.table TO "anon";
-- GRANT ALL ON TABLE public.table TO "authenticated";
-- GRANT ALL ON TABLE public.table TO "service_role";


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
