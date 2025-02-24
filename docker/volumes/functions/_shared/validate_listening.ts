import type { ListeningColumns, ListeningColumnKeys, ListeningColumn, DateFilter, TitleColumn, DurationFilter, SpotifyURI,ISRCColumn,ListenCountColumn } from "../../../../../lib/Request";

export const assertListeningColumns = (columns: ListeningColumns): asserts columns is ListeningColumns => {
    let orderCount = 0;
    let nullCount = 0;
    if(columns.listened_at === undefined) throw new Error("listened_ats is required");
    if(columns.title === undefined) throw new Error("songs is required");
    if(columns.album === undefined) throw new Error("albums is required");
    if(columns.artist === undefined) throw new Error("artists is required");
    if(columns.duration === undefined) throw new Error("durations is required");
    if(columns.upc === undefined) throw new Error("upcs is required");
    if(columns.spotify_track_id === undefined) throw new Error("spotify_track_ids is required");
    if(columns.spotify_album_id === undefined) throw new Error("spotify_album_ids is required");
    if(columns.isrc === undefined) throw new Error("isrcs is required");
    if(columns.listens === undefined) throw new Error("listens is required");
    const keys : ListeningColumnKeys[] = Object.keys(columns) as ListeningColumnKeys[];
    for(const key of keys){
        if(columns[key] === null) nullCount++;
        if(nullCount > keys.length - 1) throw new Error(`At least one column is required`);
        if(columns[key]?.order === "asc" || columns[key]?.order === "desc") orderCount++;
        if(orderCount > 1) throw new Error(`Only one column can be ordered at a time`);
    }
}
