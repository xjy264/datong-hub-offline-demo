#!/bin/sh
set -eu

[ "$#" -eq 1 ] || { echo "用法: $0 /path/to/backup-directory" >&2; exit 1; }
backup=$(cd "$1" && pwd)
cd "$(dirname "$0")"
[ -f .env ] || { echo "deploy/.env 不存在" >&2; exit 1; }
(cd "$backup" && sha256sum -c SHA256SUMS)
set -a
. ./.env
set +a

docker compose stop backend frontend minio
docker run --rm -v datong-map_minio-data:/data -v "$backup:/backup:ro" alpine:3.21 sh -c 'find /data -mindepth 1 -delete && tar -C /data -xzf /backup/minio.tar.gz'
docker compose start minio
docker compose exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u"$MYSQL_USER" "$MYSQL_DATABASE"' < "$backup/mysql.sql"
docker compose up -d backend frontend
docker compose ps
echo "恢复完成，请执行 curl -fsS http://127.0.0.1:${FRONTEND_PORT:-8012}/"
