#!/bin/bash
set -e

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

export AZURE_STORAGE_ACCOUNT=hslstoragekarttatuotanto

export CONTAINER_NAME=openmaptiles
export BLOB_NAME=tiles.mbtiles
export FILENAME=data/tiles.mbtiles
export PREVIOUS_EXPORT_FILENAME=data/prev/old_tiles.mbtiles
export MIN_SIZE=660000000

# This helps to build OpenMapTilesTools image on some environments,
# since build from git is not supported on BuildKit
export DOCKER_BUILDKIT=0

if [ -f $FILENAME ]; then
    mkdir -p data/prev
    mv -f $FILENAME $PREVIOUS_EXPORT_FILENAME
fi

curl -sSfL "https://karttapalvelu.storage.hsldev.com/finland.osm/finland.osm.pbf" -o data/finland-latest.osm.pbf
curl -sSfL "https://download.geofabrik.de/europe/estonia-latest.osm.pbf" -o data/estonia-latest.osm.pbf

osmium merge data/finland-latest.osm.pbf data/estonia-latest.osm.pbf -o data/fin-est-latest.osm.pbf --overwrite

./quickstart.sh --empty fin-est-latest

if [ ! -f $FILENAME ]; then
    (echo >&2 "File not found, exiting")
    exit 1
fi

if [ $(wc -c <"$FILENAME") -lt $MIN_SIZE ]; then
    (echo >&2 "File size under minimum, exiting")
    exit 1
fi

if [ -z "$AZURE_BLOB_SAS_ACCESS_KEY" ]; then
    (echo >&2 "\$AZURE_BLOB_SAS_ACCESS_KEY is empty. Cannot upload mbtiles to Blob, exiting")
    exit 1
fi

URL="https://"$AZURE_STORAGE_ACCOUNT".blob.core.windows.net/"$CONTAINER_NAME"/"$BLOB_NAME""
URL_WITH_SAS=$URL"?"$AZURE_BLOB_SAS_ACCESS_KEY
echo "Uploading... to " $URL
azcopy copy $FILENAME $URL_WITH_SAS
echo "Done."
