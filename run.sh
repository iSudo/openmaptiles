#!/bin/bash
set -e

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

export FILENAME=data/tiles.mbtiles
export PREVIOUS_EXPORT_FILENAME=data/prev/old_tiles.mbtiles
export MIN_SIZE=150000000

if [ -f $FILENAME ]; then
    mkdir -p data/prev
    mv -f $FILENAME $PREVIOUS_EXPORT_FILENAME
fi

curl -sSfL "https://download.geofabrik.de/europe/estonia-latest.osm.pbf" -o data/estonia-latest.osm.pbf
curl -sSfL "https://download.geofabrik.de/europe/latvia-latest.osm.pbf" -o data/latvia-latest.osm.pbf

osmium merge data/estonia-latest.osm.pbf data/latvia-latest.osm.pbf -o data/est-lat-latest.osm.pbf --overwrite

./quickstart.sh --empty est-lat-latest

if [ ! -f $FILENAME ]; then
    (echo >&2 "File not found, exiting")
    exit 1
fi

if [ $(wc -c <"$FILENAME") -lt $MIN_SIZE ]; then
    (echo >&2 "File size under minimum, exiting")
    exit 1
fi
echo "Done."
