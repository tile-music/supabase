SELECT
    a.id AS album_id,
    a.source_title AS album_title,
    a.source_service as source,

    t.id AS track_id,
    t.source_title AS track_title,

    r.id AS mb_release_id,
    mar.release_group_id,

    mtr.id AS mb_recording_id

FROM public.albums a

LEFT JOIN public.tracks t
    ON t.album_id = a.id

LEFT JOIN public.mb_album_releases mar
    ON mar.album_id = a.id

LEFT JOIN public.mb_releases r
    ON r.id = mar.id

LEFT JOIN public.mb_track_recordings mtr
    ON mtr.track_id = t.id
   AND mtr.release_id = r.id;
