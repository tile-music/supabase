-- delete entries that share the same user id, isrc, and listen timestamp
delete from prod.played_tracks
where play_id in (
  select T1.play_id from prod.played_tracks T1, prod.played_tracks T2
  where T1.user_id = T2.user_id
  and T1.isrc = T2.isrc
  and T1.listened_at = T2.listened_at
  and T1.play_id < T2.play_id
);

delete from test.played_tracks
where play_id in (
  select T1.play_id from test.played_tracks T1, test.played_tracks T2
  where T1.user_id = T2.user_id
  and T1.isrc = T2.isrc
  and T1.listened_at = T2.listened_at
  and T1.play_id < T2.play_id
);


-- change date structure for album release dates
alter table prod.albums drop column release_date;
alter table test.albums drop column release_date;

alter table prod.albums alter column image set data type text;
alter table test.albums alter column image set data type text;

alter table prod.albums add column "release_year" smallint;
alter table prod.albums add column "release_month" smallint;
alter table prod.albums add column "release_day" smallint;

alter table test.albums add column "release_year" smallint;
alter table test.albums add column "release_month" smallint;
alter table test.albums add column "release_day" smallint;

alter table prod.albums drop column popularity;
alter table test.albums drop column popularity;

-- album spotify id
alter table prod.albums add column "spotify_id" text;
alter table test.albums add column "spotify_id" text;

-- add new constraints for album uniqueness
alter table prod.albums drop constraint if exists noduplicates_albums;
alter table prod.albums add constraint noduplicates_albums unique nulls not distinct (album_name, album_type, num_tracks, release_day, release_month, release_year, artists, genre, image, spotify_id);

alter table test.albums drop constraint if exists noduplicates_test_albums;
alter table test.albums add constraint noduplicates_test_albums unique nulls not distinct (album_name, album_type, num_tracks, release_day,release_month, release_year, artists, genre, image, spotify_id);

-- track spotify id

alter table prod.tracks add column "spotify_id" text;
alter table test.tracks add column "spotify_id" text;

alter table public.spotify_credentials drop constraint if exists spotify_credentils_id_fkey;
alter table public.spotify_credentials add constraint
spotify_credentils_id_fkey foreign key ("id") references auth.users ("id") on delete cascade;

-- we have to do this because for some reason if exists does not exist for this accoding to chat and stack overflow
DO $$
BEGIN
    -- For the production schema
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'prod'
          AND table_name = 'played_tracks'
          AND column_name = 'popularity'
    ) THEN
        EXECUTE 'ALTER TABLE prod.played_tracks RENAME COLUMN "popularity" TO "track_popularity"';
    END IF;

    -- For the test schema
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'test'
          AND table_name = 'played_tracks'
          AND column_name = 'popularity'
    ) THEN
        EXECUTE 'ALTER TABLE test.played_tracks RENAME COLUMN "popularity" TO "track_popularity"';
    END IF;
END $$;

alter table prod.played_tracks add column album_popularity smallint;
alter table test.played_tracks add column album_popularity smallint;

alter table prod.played_tracks add column album_popularity_updated_at bigint;
alter table test.played_tracks add column album_popularity_updated_at bigint;

alter table prod.played_tracks add column album_id bigint;
alter table test.played_tracks add column album_id bigint;

alter table prod.played_tracks drop constraint if exists noduplicates_played;
alter table test.played_tracks drop constraint if exists played_tracks_user_id_track_id_listened_at_popularity_isrc_key;

-- make sure new played tracks are unique, regardless of popularity
alter table prod.played_tracks drop constraint if exists "played_tracks_unique_entry";
alter table prod.played_tracks add constraint "played_tracks_unique_entry" unique (user_id,track_id, isrc, listened_at);

alter table test.played_tracks drop constraint if exists "played_tracks_unique_entry";
alter table test.played_tracks add constraint "played_tracks_unique_entry" unique (user_id,track_id, isrc, listened_at);

alter table prod.played_tracks drop constraint if exists user_id_ref;
alter table prod.played_tracks add Constraint user_id_ref foreign key ("user_id") references "auth".users(id) on delete cascade;

alter table test.played_tracks drop constraint if exists user_id_ref_test;
alter table test.played_tracks add Constraint user_id_ref_test foreign key ("user_id") references "auth".users(id) on delete cascade;

alter table prod.played_tracks drop constraint if exists album_id_ref;
alter table prod.played_tracks add constraint album_id_ref foreign key ("album_id") references "prod".albums(album_id) on delete cascade;

alter table test.played_tracks drop constraint if exists album_id_ref;
alter table test.played_tracks add constraint album_id_ref foreign key ("album_id") references "test".albums(album_id) on delete cascade;


-- Update the prod schema played_tracks table
DO $$
BEGIN
    UPDATE prod.played_tracks AS pt
    SET album_id = ta.album_id
    FROM prod.track_albums AS ta
    WHERE pt.track_id = ta.track_id;
END $$;

-- Update the test schema played_tracks table
DO $$
BEGIN
    UPDATE test.played_tracks AS pt
    SET album_id = ta.album_id
    FROM test.track_albums AS ta
    WHERE pt.track_id = ta.track_id;
END $$;

-- remove double quotes from images
update prod.albums set image = replace(image, '"', '') where image like '%"%';
update test.albums set image = replace(image, '"', '') where image like '%"%';

-- add profile theme column
alter table public.profiles add column "theme" text;
update public.profiles set theme = 'dark' where theme is null;

-- remove track albums table in favor of a one track pointing to one album

ALTER TABLE prod.tracks ADD COLUMN album_id bigint;
ALTER TABLE test.tracks ADD COLUMN album_id bigint;

UPDATE prod.tracks t
SET album_id = ta.album_id
FROM prod.track_albums ta
WHERE t.track_id = ta.track_id;

UPDATE test.tracks t
SET album_id = ta.album_id
FROM test.track_albums ta
WHERE t.track_id = ta.track_id;

ALTER TABLE prod.tracks
ADD CONSTRAINT tracks_album_id_fk
FOREIGN KEY (album_id) REFERENCES prod.albums(album_id) ON DELETE CASCADE;

ALTER TABLE test.tracks
ADD CONSTRAINT tracks_album_id_fk
FOREIGN KEY (album_id) REFERENCES test.albums(album_id) ON DELETE CASCADE;
DROP TABLE prod.track_albums;
DROP TABLE test.track_albums;

alter table prod.played_tracks drop column album_id;
alter table test.played_tracks drop column album_id;
