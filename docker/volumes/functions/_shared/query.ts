import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js";
import type { SongInfo, AlbumInfo } from "../../../../../lib/Song.ts";

type dbTrack = {
    isrc: string;
    track_name: string;
    track_artists: string[];
    track_duration_ms: number;
	spotify_id: string
    track_albums: {
        albums: dbAlbum[];
    }[];
};

type dbAlbum = {
	album_name: string;
	num_tracks: number;
	release_day: number;
	release_month: number;
	release_year: number;
	artists: string[];
	image: string;
	spotify_id: string;
    upc: string;
};

type DBData = {
	listened_at: number,
	tracks: unknown
}[];

/**
 * assembles a query that can be used to gather a user's songs and associated albums
 * @param supabase the supabase client
 * @param userID the id to filter listening data for
 * @returns the database query
 */
// deno-lint-ignore no-explicit-any
export function constructQuery(supabase: SupabaseClient<any, string, any>, userID: string) {
	return supabase
	.from("played_tracks")
	.select(`
	  listened_at,
	  tracks!inner( isrc, track_name, track_artists, track_duration_ms, spotify_id,
		track_albums!inner( albums!inner( album_name, num_tracks, release_day,
		  release_month, release_year, artists, image, spotify_id, upc ) )
	  )
	`)
	.eq("user_id", userID)
}

/**
 * processes the returned database data into an array of SongInfo objects
 * @param dbData the data returned by running the query returned by `constructQuery()`
 * @returns a list of SongInfo objects
 */
export function processPlayedTracksData(dbData: DBData): SongInfo[] {
	const songs: SongInfo[] = []
	for (const entry of dbData) {
		// the supabase api thinks that tracks() and track_albums() return an array of objects,
		// but in reality, they only return one object. as a result, we have to do some
		// pretty ugly typecasting to make the compiler happy
		const track = entry.tracks as dbTrack;
		const album = track.track_albums[0].albums as unknown as dbAlbum;

		// extract album information
		const albumInfo: AlbumInfo = {
			title: album.album_name,
			tracks: album.num_tracks,
			release_day: album.release_day,
			release_month: album.release_month,
			release_year: album.release_year,
			artists: album.artists,
			image: album.image,
			spotify_id: album.spotify_id,
            upc: album.upc
		};
		
		// extract song information
		const songInfo: SongInfo = {
			isrc: track.isrc,
			title: track.track_name,
			artists: track.track_artists,
			duration: track.track_duration_ms,
			listened_at: entry.listened_at,
			spotify_id: track.spotify_id,
			albums: [albumInfo]
		};
		
		songs.push(songInfo);
	}

	return songs;
}