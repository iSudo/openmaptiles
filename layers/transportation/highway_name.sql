CREATE OR REPLACE FUNCTION transportation_name_tags(geometry geometry, tags hstore, name text, name_fi text, name_en text, name_sv text) RETURNS hstore AS
$$
SELECT hstore(string_agg(nullif(slice_language_tags(tags ||
                     hstore(ARRAY [
                       'name',    CASE WHEN length(name) > 15    THEN osml10n_street_abbrev_all(name)   ELSE NULLIF(name, '') END,
                       'name:fi', CASE WHEN length(name_fi) > 15 THEN osml10n_street_abbrev_de(name_fi) ELSE NULLIF(name_fi, '') END,
                       'name:en', CASE WHEN length(name_en) > 15 THEN osml10n_street_abbrev_en(name_en) ELSE NULLIF(name_en, '') END,
                       'name:sv', CASE WHEN length(name_sv) > 15 THEN osml10n_street_abbrev_de(name_sv) ELSE NULLIF(name_sv, '') END
                     ]))::text,
                     ''), ','));
$$ LANGUAGE SQL IMMUTABLE
                PARALLEL SAFE;
