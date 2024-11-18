alter table prod.albums drop column release_date;
alter table test.albums drop column release_date;

alter table prod.albums alter column image set data type text;
alter table test.albums alter column image set data type text;

alter table prod.albums add column "release_year" smallint;
alter table prod.albums add column "release_month" smallint;
alter table prod.albums add column "release_day" smallint;

--alter table prod.albums drop constraint noduplicates;
alter table prod.albums add constraint noduplicates UNIQUE NULLS NOT DISTINCT (album_name, album_type, num_tracks, release_day, release_month, release_year, artists, genre, upc, ean, image);

alter table test.albums add column "release_year" smallint;
alter table test.albums add column "release_month" smallint;
alter table test.albums add column "release_day" smallint;

alter table test.albums add constraint noduplicates_test_albums UNIQUE NULLS NOT DISTINCT (album_name, album_type, num_tracks, release_day,release_month, release_year, artists, genre, upc, ean, image);

--alter table test.albums drop constraint nodups_test;

ALTER TABLE ONLY "public"."spotify_credentials"
ADD CONSTRAINT "spotify_credentils_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



alter table prod.played_tracks drop constraint noduplicates_played;
alter table test.played_tracks drop constraint played_tracks_user_id_track_id_listened_at_popularity_isrc_key;


alter table prod.played_tracks
add constraint "played_tracks_unique_entry" UNIQUE (user_id,track_id, isrc, listened_at);
alter table prod.played_tracks drop constraint user_id_ref;
alter table prod.played_tracks add Constraint user_id_ref FOREIGN KEY ("user_id") References "auth".users(id) on delete cascade;


alter table test.played_tracks add Constraint user_id_ref_test FOREIGN KEY ("user_id") References "auth".users(id) on delete cascade;
alter table test.played_tracks
add constraint "played_tracks_unique_entry" UNIQUE (user_id,track_id, isrc, listened_at);