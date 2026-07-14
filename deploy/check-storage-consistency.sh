#!/bin/sh
set -eu
cd "$(dirname "$0")"
set -a
. ./.env
set +a
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

docker compose exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql --default-character-set=utf8mb4 -N -u"$MYSQL_USER" "$MYSQL_DATABASE" -e "SELECT object_name FROM station_image UNION SELECT pdf_object_name FROM map_document WHERE pdf_object_name IS NOT NULL UNION SELECT background_object_name FROM map_document WHERE background_object_name IS NOT NULL"' | sort -u > "$tmp/database"
docker compose exec -T minio sh -c 'mc alias set verify http://127.0.0.1:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null && mc find "verify/'"${MINIO_BUCKET:-datong-map}"'" --print "{}"' | sed "s#^verify/${MINIO_BUCKET:-datong-map}/##" | sort -u > "$tmp/storage"

echo "MinIO 中没有数据库引用的对象:"
comm -13 "$tmp/database" "$tmp/storage" || true
echo "数据库引用但 MinIO 缺失的对象:"
comm -23 "$tmp/database" "$tmp/storage" || true
