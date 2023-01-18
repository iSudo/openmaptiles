-- etldoc: osm_peak_point -> peak_point
-- etldoc: ne_10m_admin_0_countries -> peak_point
CREATE OR REPLACE VIEW peak_point AS
(
SELECT pp.osm_id,
       pp.geometry,
       pp.name,
       pp.name_en,
       pp.name_sv,
       pp.tags,
       pp.ele,
       ne.iso_a2,
       pp.wikipedia
FROM osm_peak_point pp, ne_10m_admin_0_countries ne
WHERE ST_Intersects(pp.geometry, ne.geometry)
    );



-- etldoc: layer_mountain_peak[shape=record fillcolor=lightpink,
-- etldoc:     style="rounded,filled", label="layer_mountain_peak | <z7_> z7+ | <z13_> z13+" ] ;

CREATE OR REPLACE FUNCTION layer_mountain_peak(bbox geometry,
                                               zoom_level integer,
                                               pixel_width numeric)
    RETURNS TABLE
            (
                osm_id          bigint,
                geometry        geometry,
                name            text,
                name_en         text,
                name_sv         text,
                name_sv_nodefault  text,
                class           text,
                tags            hstore,
                ele             int,
                ele_ft          int,
                customary_ft    int,
                "rank"          int
            )
AS
$$
SELECT
    -- etldoc: peak_point -> layer_mountain_peak:z7_
    osm_id,
    geometry,
    name,
    name_en,
    name_sv,
    name_sv_nodefault,
    tags->'natural' AS class,
    tags,
    ele::int,
    ele_ft::int,
    customary_ft,
    rank::int
FROM (
         SELECT osm_id,
                geometry,
                name,
                COALESCE(NULLIF(name_en, ''), name) AS name_en,
                COALESCE(NULLIF(name_sv, ''), name) AS name_sv,
                NULLIF(name_sv, name) as name_sv_nodefault,
                tags,
                substring(ele FROM E'^(-?\\d+)(\\D|$)')::int AS ele,
                round(substring(ele FROM E'^(-?\\d+)(\\D|$)')::int * 3.2808399)::int AS ele_ft,
                CASE WHEN iso_a2 = 'US' THEN 1 END AS customary_ft,
                row_number() OVER (
                    PARTITION BY LabelGrid(geometry, 100 * pixel_width)
                    ORDER BY (
                            substring(ele FROM E'^(-?\\d+)(\\D|$)')::int +
                            (CASE WHEN wikipedia <> '' THEN 10000 ELSE 0 END) +
                            (CASE WHEN name <> '' THEN 10000 ELSE 0 END)
                        ) DESC
                    )::int AS "rank"
         FROM peak_point
         WHERE geometry && bbox
           AND ele IS NOT NULL
           AND ele ~ E'^-?\\d{1,4}(\\D|$)'
     ) AS ranked_peaks
WHERE zoom_level >= 7
  AND (rank <= 5 OR zoom_level >= 14)

UNION ALL

SELECT
    -- etldoc: osm_mountain_linestring -> layer_mountain_peak:z13_
    osm_id,
    geometry,
    name,
    name_en,
    name_sv,
    name_sv_nodefault,
    tags->'natural' AS class,
    tags,
    NULL AS ele,
    NULL AS ele_ft,
    NULL AS customary_ft,
    rank::int
FROM (
         SELECT osm_id,
                geometry,
                name,
                COALESCE(NULLIF(name_en, ''), name) AS name_en,
                COALESCE(NULLIF(name_sv, ''), name, name_en) AS name_sv,
                NULLIF(name_sv, name) as name_sv_nodefault,
                tags,
                row_number() OVER (
                    PARTITION BY LabelGrid(geometry, 100 * pixel_width)
                    ORDER BY (
                            (CASE WHEN wikipedia <> '' THEN 10000 ELSE 0 END) +
                            (CASE WHEN name <> '' THEN 10000 ELSE 0 END)
                        ) DESC
                    )::int AS "rank"
         FROM osm_mountain_linestring
         WHERE geometry && bbox
     ) AS ranked_mountain_linestring
WHERE zoom_level >= 13
ORDER BY "rank" ASC;

$$ LANGUAGE SQL STABLE
                PARALLEL SAFE;
-- TODO: Check if the above can be made STRICT -- i.e. if pixel_width could be NULL
