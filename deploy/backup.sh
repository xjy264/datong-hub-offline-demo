#!/bin/sh
set -eu

cd "$(dirname "$0")"
[ -f .env ] || { echo "deploy/.env 不存在" >&2; exit 1; }
set -a
. ./.env
set +a

BACKUP_ROOT=${BACKUP_ROOT:-/home/ubuntu/backups/datong}
stamp=$(date +%Y%m%d-%H%M%S)
target="$BACKUP_ROOT/daily-$stamp"
mkdir -p "$target"
chmod 700 "$BACKUP_ROOT" "$target"

docker compose exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysqldump --single-transaction --routines --triggers -u"$MYSQL_USER" "$MYSQL_DATABASE"' > "$target/mysql.sql"
docker run --rm -v datong-map_minio-data:/data:ro -v "$target:/backup" alpine:3.21 tar -C /data -czf /backup/minio.tar.gz .
cp .env "$target/deploy.env"
chmod 600 "$target/deploy.env"
(cd "$target" && sha256sum mysql.sql minio.tar.gz deploy.env > SHA256SUMS)

find "$BACKUP_ROOT" -maxdepth 1 -type d -name 'daily-*' -mtime +7 -exec rm -rf {} +
if [ "$(date +%u)" = "7" ]; then
  weekly="$BACKUP_ROOT/weekly-$(date +%Y%W)"
  rm -rf "$weekly"
  cp -a "$target" "$weekly"
fi
find "$BACKUP_ROOT" -maxdepth 1 -type d -name 'weekly-*' -mtime +28 -exec rm -rf {} +

if [ -n "${BACKUP_RCLONE_REMOTE:-}" ] && command -v rclone >/dev/null 2>&1; then
  rclone copy "$target" "$BACKUP_RCLONE_REMOTE/$stamp"
fi
echo "备份完成: $target"
