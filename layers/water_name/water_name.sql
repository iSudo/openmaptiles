-- etldoc: layer_water_name[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="layer_water_name | <z0_8> z0_8 | <z9_13> z9_13 | <z14_> z14+" ] ;
CREATE OR REPLACE FUNCTION layer_water_name(bbox geometry, zoom_level integer)
    RETURNS TABLE
            (
                osm_id       bigint,
                geometry     geometry,
                name         text,
                name_en      text,
                name_sv      text,
                name_sv_nodefault  text,
                tags         hstore,
                class        text,
                intermittent int
            )
AS
$$
SELECT
    -- etldoc: osm_water_lakeline ->  layer_water_name:z9_13
    -- etldoc: osm_water_lakeline ->  layer_water_name:z14_
    CASE
        WHEN osm_id < 0 THEN -osm_id * 10 + 4
        ELSE osm_id * 10 + 1
        END AS osm_id_hash,
    geometry,
    COALESCE(NULLIF(name_et, ''), name) AS name,
    COALESCE(NULLIF(name_en, ''), name) AS name_en,
    COALESCE(NULLIF(name_sv, ''), name) AS name_sv,
    NULLIF(name_sv, name) as name_sv_nodefault,
    tags,
    COALESCE(NULLIF(leisure, ''), 'lake'::text) AS class,
    is_intermittent::int AS intermittent
FROM osm_water_lakeline
WHERE geometry && bbox
  AND ((zoom_level BETWEEN 9 AND 13 AND LineLabel(zoom_level, NULLIF(name, ''), geometry))
    OR (zoom_level >= 14))
UNION ALL
SELECT
    -- etldoc: osm_water_point ->  layer_water_name:z9_13
    -- etldoc: osm_water_point ->  layer_water_name:z14_
    CASE
        WHEN osm_id < 0 THEN -osm_id * 10 + 4
        ELSE osm_id * 10 + 1
        END AS osm_id_hash,
    geometry,
    COALESCE(NULLIF(name_et, ''), name) AS name,
    COALESCE(NULLIF(name_en, ''), name) AS name_en,
    COALESCE(NULLIF(name_sv, ''), name) AS name_sv,
    NULLIF(name_sv, name) as name_sv_nodefault,
    tags,
    COALESCE(NULLIF(leisure, ''), NULLIF("natural", ''), 'lake'::text) AS class,
    is_intermittent::int AS intermittent
FROM osm_water_point
WHERE geometry && bbox
  AND (
        (zoom_level BETWEEN 9 AND 13 AND area > 70000 * 2 ^ (20 - zoom_level))
        OR (zoom_level >= 14)
    )
UNION ALL
SELECT
    -- etldoc: osm_marine_point ->  layer_water_name:z0_8
    -- etldoc: osm_marine_point ->  layer_water_name:z9_13
    -- etldoc: osm_marine_point ->  layer_water_name:z14_
    osm_id * 10 AS osm_id_hash,
    geometry,
    COALESCE(NULLIF(name_et, ''), name) AS name,
    COALESCE(NULLIF(name_en, ''), name) AS name_en,
    COALESCE(NULLIF(name_sv, ''), name) AS name_sv,
    NULLIF(name_sv, name) as name_sv_nodefault,
    tags,
    COALESCE(NULLIF(leisure, ''), NULLIF("natural", ''), place::text) AS class,
    is_intermittent::int AS intermittent
FROM osm_marine_point
WHERE geometry && bbox
  AND (
        place = 'ocean'
        OR (zoom_level >= "rank" AND "rank" IS NOT NULL)
        OR (zoom_level >= 8 AND "natural" IS NULL)
        OR ("natural" IS NOT NULL AND zoom_level >= 14)
    );
$$ LANGUAGE SQL STABLE
                -- STRICT
                PARALLEL SAFE;
