#!/bin/sh
set -eu
script=$(cd "$(dirname "$0")" && pwd)/backup.sh
job="20 2 * * * $script >> /var/log/datong-backup.log 2>&1"
(crontab -l 2>/dev/null | grep -v 'datong-hub-offline-demo/deploy/backup.sh' || true; echo "$job") | crontab -
echo "已安装每日 02:20 备份任务"
