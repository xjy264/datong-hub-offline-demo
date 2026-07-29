# 内网服务器 AI 运维与离线补丁手册

> 适用服务器：`datong`，Ubuntu 24.04，AMD64
> 当前局域网地址：`192.168.1.7`
> 当前 Tailscale 地址：`100.123.188.49`
> 现场审计日期：2026-07-29（服务器系统日志使用 UTC）
> 文档目的：在后续 AI 没有直接服务器连接的情况下，由内网操作员复制 AI 给出的命令到服务器执行，再把输出返回给 AI。

---

## 0. 给接手 AI 的最高优先级规则

接手维护时先阅读本节，再生成任何命令。

1. 这是两套正在运行且共用一台机器的生产数据副本，不要执行：
   - `docker compose down -v`
   - `docker volume rm ...`
   - `docker system prune --volumes`
   - `rm -rf /var/lib/docker`
   - 覆盖现有 `deploy/.env`
   - 在没有快照时执行数据库迁移或数据恢复
2. 服务器部署目录没有 `.git`，更新方式是“干净源码包 + AMD64 应用镜像包 + SHA256”，不是在服务器内拉取代码。
3. 新服务器按 Docker Hub 不可用处理。启动统一使用：

   ```bash
   docker compose up -d --no-build --pull never
   ```

4. 每次补丁前必须：
   - 记录容器和镜像状态；
   - 备份两个 `.env`；
   - 给四个当前应用镜像增加回滚标签；
   - 备份涉及系统的 MySQL 和 MinIO；
   - 校验补丁包 SHA256。
5. 只修改本次补丁涉及的系统。标准化和大同管辖是两个独立 Compose 项目。
6. 数据库 Flyway 迁移通常随后端启动自动执行。补丁包含新迁移脚本时，先判断迁移是否可逆；应用镜像回滚不等于数据库结构回滚。
7. 任何命令包含密码、JWT、MinIO 密钥时，不要把值写进报告、日志或聊天；让容器从已有环境变量读取。
8. 操作员返回输出后，AI 应先判断真实状态，再给下一组命令；每组命令保持短小并带验证。

---

## 1. 当前系统总览

### 1.1 硬件与操作系统

| 项目 | 当前值 |
|---|---|
| 主机名 | `datong` |
| 操作系统 | Ubuntu 24.04.4 LTS |
| 内核 | `6.8.0-136-generic` |
| 架构 | `x86_64 / amd64` |
| CPU | 2 核 |
| 内存 | 14 GiB |
| Swap | 4 GiB |
| 系统盘 | `/dev/sdb`，1TB 机械盘，Ubuntu LVM |
| 旧数据盘 | `/dev/sda1`，约 120GB NTFS，未挂载、未修改 |
| 根文件系统 | 约 914GB；审计时使用 20GB（3%） |
| 系统时区 | `Etc/UTC` |
| 容器业务时区 | `Asia/Shanghai` |

Ubuntu LVM 已从安装时的约 100GB 扩展到 `/dev/sdb3` 全部空间，逻辑卷约 `928.5G`。

系统盘 SMART 状态为 `PASSED`，短自检 `Completed without error`；坏扇区、待处理扇区和不可校正扇区均为 0。系统盘累计通电约 29,073 小时，因此已经安装并启用 `smartmontools`/SMART 监控。

### 1.2 已安装的关键工具

- Docker 29.1.3
- Docker Compose 2.40.3
- Git 2.43.0
- curl 8.5.0
- rsync 3.2.7
- UFW
- Tailscale
- smartmontools
- aria2（迁移阶段使用）

用户 `datong` 属于 `sudo` 和 `docker` 组。Docker 服务状态为 `active`、`enabled`。

### 1.3 网络

| 用途 | 地址 |
|---|---|
| 局域网 | `192.168.1.7/24` |
| 网关 | `192.168.1.1` |
| 网卡 | `enp2s0` |
| MAC | `4c:cc:6a:92:6f:5f` |
| Tailscale | `100.123.188.49/32` |

Netplan 当前使用 DHCP：

```yaml
network:
  version: 2
  ethernets:
    enp2s0:
      dhcp4: true
```

因此 `192.168.1.7` 依赖天翼网关的 DHCP 租约。服务器重启后该地址保持不变，但长期固定应在天翼网关中把 MAC `4c:cc:6a:92:6f:5f` 保留为 `192.168.1.7`。

### 1.4 防火墙

UFW 当前状态：`active`，默认拒绝入站、允许出站、拒绝转发。

允许规则：

- LAN `192.168.1.0/24`：TCP 22、8000、8012
- `tailscale0`：TCP 22、8000、8012

对外业务入口只有：

- `0.0.0.0:8000`：标准化前端
- `0.0.0.0:8012`：大同管辖前端

MySQL、Redis、MinIO、后端、OnlyOffice 全部绑定 `127.0.0.1`。

---

## 2. 两套系统的部署结构

### 2.1 标准化系统

| 项目 | 值 |
|---|---|
| 目录 | `/opt/standard-docs-system` |
| 部署提交 | `b8ff43c72964f6cb5ec9a98b4cce2eda6c218e49` |
| 提交记录文件 | `/opt/standard-docs-system/.deployment-commit` |
| Compose 目录 | `/opt/standard-docs-system/deploy` |
| Compose 项目名 | `deploy`（由目录名推导） |
| 环境文件 | `/opt/standard-docs-system/deploy/.env`，权限 600 |
| 局域网入口 | `http://192.168.1.7:8000` |
| Tailscale 入口 | `http://100.123.188.49:8000` |
| 后端健康 | `http://127.0.0.1:8010/actuator/health` |

容器：

| 容器 | 镜像 | 主机端口 | 数据卷 |
|---|---|---|---|
| `dt-standard-frontend` | `deploy-frontend:latest` | `0.0.0.0:8000` | 无 |
| `dt-standard-backend` | `deploy-backend:latest` | `127.0.0.1:8010` | 无 |
| `dt-standard-mysql` | `mysql:8.0` | `127.0.0.1:3306` | `deploy_mysql-data` |
| `dt-standard-redis` | `redis:7` | `127.0.0.1:6379` | `deploy_redis-data` |
| `dt-standard-minio` | 固定版 MinIO | `127.0.0.1:9000/9001` | `deploy_minio-data` |
| `dt-standard-onlyoffice` | `onlyoffice/documentserver:latest` | `127.0.0.1:8082` | 4 个 OnlyOffice 匿名卷 |

安全展示的环境配置：

```dotenv
APP_DOMAIN=192.168.1.7
BACKEND_PORT=8010
FRONTEND_PORT=8000
MYSQL_PORT=3306
REDIS_PORT=6379
MINIO_API_PORT=9000
MINIO_CONSOLE_PORT=9001
MYSQL_DATABASE=dt_standard_system
MYSQL_USER=standard
MINIO_ROOT_USER=standard-docs-minio
ONLYOFFICE_ENABLED=true
ONLYOFFICE_URL=/onlyoffice
ONLYOFFICE_PORT=8082
AUTH_COOKIE_SECURE=false
KNIFE4J_ENABLED=false
SPRINGDOC_API_DOCS_ENABLED=false
SPRINGDOC_SWAGGER_UI_ENABLED=false
```

密码类字段保存在现有 `.env`：

- `MYSQL_PASSWORD`
- `MYSQL_ROOT_PASSWORD`
- `REDIS_PASSWORD`
- `MINIO_ROOT_PASSWORD`
- `JWT_SECRET`
- `BACKUP_PASSWORD`

### 2.2 大同管辖系统

| 项目 | 值 |
|---|---|
| 目录 | `/opt/datong-hub-offline-demo` |
| 部署提交 | `26457fa7f3b7be79e93a7887c76bb772d28df2d5` |
| 提交记录文件 | `/opt/datong-hub-offline-demo/.deployment-commit` |
| Compose 目录 | `/opt/datong-hub-offline-demo/deploy` |
| Compose 项目名 | `datong-map`（Compose 文件显式设置） |
| 环境文件 | `/opt/datong-hub-offline-demo/deploy/.env`，权限 600 |
| 局域网入口 | `http://192.168.1.7:8012` |
| Tailscale 入口 | `http://100.123.188.49:8012` |
| 后端健康 | `http://127.0.0.1:8011/actuator/health` |

容器：

| 容器 | 镜像 | 主机端口 | 限额/数据卷 |
|---|---|---|---|
| `datong-map-frontend` | `datong-map-frontend:latest` | `0.0.0.0:8012` | 64MiB |
| `datong-map-backend` | `datong-map-backend:latest` | `127.0.0.1:8011` | 768MiB |
| `datong-map-mysql` | `mysql:8.0` | `127.0.0.1:3311` | 512MiB；`datong-map_mysql-data` |
| `datong-map-redis` | `redis:7` | `127.0.0.1:6381` | 128MiB；`datong-map_redis-data` |
| `datong-map-minio` | 固定版 MinIO | `127.0.0.1:9011/9012` | 384MiB；`datong-map_minio-data` |

安全展示的环境配置：

```dotenv
MYSQL_DATABASE=datong_map
MYSQL_USER=datong
MINIO_BUCKET=datong-map
FRONTEND_PORT=8012
BACKEND_PORT=8011
MYSQL_PORT=3311
REDIS_PORT=6381
MINIO_API_PORT=9011
MINIO_CONSOLE_PORT=9012
AUTH_COOKIE_SECURE=false
APP_PRODUCTION=false
```

密码类字段保存在现有 `.env`：

- `MYSQL_ROOT_PASSWORD`
- `MYSQL_PASSWORD`
- `REDIS_PASSWORD`
- `MINIO_ROOT_PASSWORD`
- `JWT_SECRET`

大同使用局域网 HTTP，因此 `APP_PRODUCTION=false`、`AUTH_COOKIE_SECURE=false`。如果未来增加 HTTPS，应同时审查这两个值和反向代理配置。

---

## 3. 初次部署实际执行了什么

### 3.1 服务器基础环境

1. 在 `/dev/sdb` 安装 Ubuntu 24.04 AMD64。
2. 将 Ubuntu LVM 根逻辑卷扩展到 `/dev/sdb3` 全部可用空间。
3. 保留 `/dev/sda1` 的 NTFS 分区，不挂载、不格式化。
4. 安装 Docker、Compose、Git、curl、rsync、UFW、aria2 等工具。
5. 把 `datong` 加入 Docker 用户组，启用 Docker 开机启动。
6. 配置 UFW，只开放 LAN/Tailscale 所需端口。
7. 使用 Tailscale 作为外网管理通道。

### 3.2 代码交付

远程 `main` 在交付时确认到以下提交：

- 标准化：`b8ff43c72964f6cb5ec9a98b4cce2eda6c218e49`
- 大同：`26457fa7f3b7be79e93a7887c76bb772d28df2d5`

源码使用 `git archive` 生成干净包，没有带入 Mac 本地未提交文件。服务器项目目录没有 `.git`。

对照保留的原始源码包重新执行目录差异检查后，确认部署树只有以下源码级变化：

```diff
# 标准化 deploy/docker-compose.yml
- "${FRONTEND_PORT:-8000}:80"
+ "0.0.0.0:${FRONTEND_PORT:-8000}:80"

# 大同 deploy/docker-compose.yml
- "${FRONTEND_PORT:-8012}:80"
+ "0.0.0.0:${FRONTEND_PORT:-8012}:80"
```

此外新增了：

- 两套 `deploy/.env`（生产凭据和内网配置）
- 两套 `.deployment-commit`（记录部署提交）

其余项目文件与对应源码归档一致。

### 3.3 镜像交付

四个 AMD64 应用镜像按指定提交构建：

| 镜像 | Image ID | OCI revision |
|---|---|---|
| `deploy-backend:latest` | `7d1fa99b30cf` | `b8ff43c...` |
| `deploy-frontend:latest` | `b995dfd0225a` | `b8ff43c...` |
| `datong-map-backend:latest` | `f1e14cc36ad6` | `26457fa...` |
| `datong-map-frontend:latest` | `1d53aa8d6126` | `26457fa...` |

同时准备了 MySQL 8、Redis 7、MinIO、OnlyOffice、Alpine 及构建基础镜像。最终启动使用本地镜像：

```bash
docker compose up -d --no-build --pull never
```

### 3.4 数据迁移

线上短暂停写窗口约 2 分 30 秒。两套系统均完成：

1. 停止线上前后端，阻止新写入。
2. MySQL 使用一致性导出，包含触发器和迁移记录。
3. 短暂停止 MinIO，打包完整数据卷。
4. 记录数据行数、Flyway 版本、文件数量和 SHA256。
5. 立即恢复旧公网服务器。
6. 加密数据包通过 Mac 中转到新服务器。
7. 新服务器校验、解密、再次校验并恢复 MySQL/MinIO。
8. Redis 使用全新数据卷，没有迁移旧会话和验证码。

迁移后核对结果：

- 标准化：Flyway V18，9 个 MinIO 业务文件内容一致。
- 大同：Flyway V12，208 个 MinIO 业务文件内容一致。
- 两套用户密码哈希、状态和审批状态聚合摘要一致。

### 3.5 最终验证

- 11 个容器设置 `restart: unless-stopped`。
- 整机重启后 11 个容器全部自动恢复。
- 两套首页、后端健康接口、标准化登录和 OnlyOffice 文件读取、大同地图与图片访问均通过。
- 内网和 Tailscale 入口均返回 HTTP 200。

---

## 4. 当前保留的离线恢复材料

目录：`/opt/migration-staging`

| 文件 | 用途 | SHA256 |
|---|---|---|
| `standard-docs-system-b8ff43c.tar.gz` | 标准化干净源码 | `aa58192f31c5e36ac445dfbc4046740dc7dc8fdbba2b7e10d7161b2a8abaab59` |
| `datong-hub-offline-demo-26457fa.tar.gz` | 大同干净源码 | `ab15ad86206f496d559b9ae7ef2f05b0571fa01eedf296f53e2ee83867065b73` |
| `images-amd64.tar.gz` | 完整 AMD64 离线镜像 | `64d0fbca0c832d9523c49c832d6e44fcdc0a7d7df29f5a1344c5741b577ebe92` |
| `data/standard-mysql.sql.gz` | 标准化迁移时数据库快照 | `e3925e033c25e08e0606b1c5ea4263f304e690a3b07eefe93db27ca8b9dda21e` |
| `data/standard-minio.tar.gz` | 标准化迁移时文件快照 | `1bdc7d3b6d4c48e245dcda7ce6703d624b8519e710cdf24d7af833d4c8260738` |
| `data/datong-mysql.sql.gz` | 大同迁移时数据库快照 | `3b29a7d26395e0b024b8111a61412a66819987b2e270e00a301a0834e7cb615d` |
| `data/datong-minio.tar.gz` | 大同迁移时文件快照 | `9968984cd0aba63cfea155763818b2a93b8f06b2dd250a1514d9b4dd88a00d03` |

完整镜像恢复命令：

```bash
cd /opt/migration-staging
sha256sum -c SHA256SUMS
gzip -dc images-amd64.tar.gz | docker load
```

`data/` 是初次迁移时间点的快照，不包含之后新增的业务数据。

---

## 5. 日常运维命令

### 5.1 一次性健康检查

```bash
echo '=== host ==='
uptime
free -h
df -h /

echo '=== containers ==='
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' \
  | grep -E 'NAMES|dt-standard|datong-map'

echo '=== pressure ==='
docker stats --no-stream --format \
  'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}'

echo '=== health ==='
curl -fsS http://127.0.0.1:8000/ >/dev/null && echo 'standard frontend OK'
curl -fsS http://127.0.0.1:8010/actuator/health && echo
curl -fsS http://127.0.0.1:8012/ >/dev/null && echo 'datong frontend OK'
curl -fsS http://127.0.0.1:8011/actuator/health && echo
```

预期：11 个容器运行，除 OnlyOffice 本身没有 Compose healthcheck 外，其余 10 个显示 `healthy`；两个后端返回 `"status":"UP"`。

### 5.2 标准化

```bash
cd /opt/standard-docs-system
./run.sh status
./run.sh doctor
./run.sh logs
./run.sh restart
```

`./run.sh logs` 会持续跟踪日志，按 `Ctrl+C` 退出。

直接使用 Compose：

```bash
cd /opt/standard-docs-system/deploy
docker compose ps
docker compose logs --tail=200 backend frontend
docker compose restart backend frontend
```

### 5.3 大同管辖

```bash
cd /opt/datong-hub-offline-demo/deploy
docker compose ps
docker compose logs --tail=200 backend frontend
docker compose restart backend frontend
./check-storage-consistency.sh
```

### 5.4 服务器压力和硬盘

```bash
uptime
free -h
vmstat 2 5
df -hT /
docker stats --no-stream
sudo smartctl -H -A /dev/sdb
systemctl --failed --no-pager
journalctl -k -b -p warning..alert --no-pager | tail -100
```

当前正常基线：负载远低于 2，CPU 空闲 90% 以上，可用内存约 11–12GB，Swap 为 0，根分区约 3%。大同 MySQL 容器约使用 `396MiB/512MiB`，是最接近限额的容器；业务量增长时优先观察它。

### 5.5 服务器重启后怎样启动 Docker 和两套系统

Docker 已设置为开机自动启动，11 个业务容器都使用 `restart: unless-stopped`。正常重启后，Docker 和容器会自动恢复，通常只需要等待并检查，不需要逐个启动容器。

#### 情况一：正常重启后的标准检查流程

登录服务器后先执行：

```bash
echo '=== 1. 主机和地址 ==='
uptime
ip -brief addr show enp2s0
ip -brief addr show tailscale0

echo '=== 2. Docker 服务 ==='
systemctl is-enabled docker
systemctl is-active docker

echo '=== 3. Tailscale 服务 ==='
systemctl is-enabled tailscaled
systemctl is-active tailscaled
tailscale ip -4

echo '=== 4. 等待容器恢复 ==='
for i in $(seq 1 36); do
  count=$(docker ps --format '{{.Names}}' \
    | grep -Ec '^(dt-standard|datong-map)' || true)
  starting=$(docker ps --format '{{.Names}}|{{.Status}}' \
    | grep -E '^(dt-standard|datong-map)' \
    | grep -c 'health: starting' || true)
  echo "attempt=$i containers=$count health_starting=$starting"
  [ "$count" -eq 11 ] && [ "$starting" -eq 0 ] && break
  sleep 5
done

echo '=== 5. 容器最终状态 ==='
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' \
  | grep -E 'NAMES|dt-standard|datong-map'
```

预期：

- `systemctl is-enabled docker` 输出 `enabled`；
- `systemctl is-active docker` 输出 `active`；
- 业务容器数量为 11；
- OnlyOffice 显示 `Up`；
- 其余 10 个容器最终显示 `healthy`。

OnlyOffice、MySQL 和两个 Java 后端启动时间较长。刚开机时出现 `health: starting` 属于正常过程，建议等待 1–3 分钟后再判断。

继续验证两套业务：

```bash
echo '=== 6. 本机业务接口 ==='
curl -fsS http://127.0.0.1:8000/ >/dev/null \
  && echo 'standard frontend OK'
curl -fsS http://127.0.0.1:8010/actuator/health && echo
curl -fsS \
  http://127.0.0.1:8000/onlyoffice/web-apps/apps/api/documents/api.js \
  >/dev/null && echo 'onlyoffice API OK'

curl -fsS http://127.0.0.1:8012/ >/dev/null \
  && echo 'datong frontend OK'
curl -fsS http://127.0.0.1:8011/actuator/health && echo

echo '=== 7. 资源状态 ==='
uptime
free -h
df -h /
docker stats --no-stream --format \
  'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}'
```

最后使用真实局域网设备打开：

- `http://192.168.1.7:8000`
- `http://192.168.1.7:8012`

如果 `ip -brief addr show enp2s0` 显示的地址已经变化，以新地址访问，并检查天翼网关 DHCP 静态租约。

#### 情况二：Docker 服务没有自动启动

手动启动一次：

```bash
sudo systemctl start docker
systemctl is-active docker
```

同时设置当前启动和以后开机自动启动：

```bash
sudo systemctl enable --now containerd docker
systemctl is-enabled containerd docker
systemctl is-active containerd docker
```

Docker 恢复后等待约 1–3 分钟，再执行前面的 11 容器和业务接口检查。

#### 情况三：Docker 已启动，但业务容器没有全部恢复

先查看已停止容器和原因：

```bash
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'

for c in $(docker ps -a --format '{{.Names}}' \
  | grep -E '^(dt-standard|datong-map)'); do
  docker inspect -f \
    '{{.Name}} restart={{.RestartCount}} oom={{.State.OOMKilled}} exit={{.State.ExitCode}} error={{.State.Error}} policy={{.HostConfig.RestartPolicy.Name}}' \
    "$c"
done
```

使用服务器已有镜像启动标准化：

```bash
cd /opt/standard-docs-system/deploy
docker compose config --quiet
docker compose up -d --no-build --pull never
docker compose ps
```

使用服务器已有镜像启动大同：

```bash
cd /opt/datong-hub-offline-demo/deploy
docker compose config --quiet
docker compose up -d --no-build --pull never
docker compose ps
```

这两组命令会保留现有 MySQL、Redis 和 MinIO 数据卷。不要给 `down` 添加 `-v`。

#### 情况四：Docker 服务启动失败

先收集诊断，不要删除镜像或数据卷：

```bash
sudo systemctl status containerd docker --no-pager -l
sudo journalctl -u containerd -u docker -b --no-pager | tail -300
df -hT /
df -i /
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
sudo smartctl -H -A /dev/sdb
```

如果磁盘空间、inode 和 SMART 都正常，可尝试按依赖顺序重启服务：

```bash
sudo systemctl restart containerd
sudo systemctl restart docker
systemctl is-active containerd docker
```

然后重新执行容器恢复检查。若服务仍为 `failed`，把上述完整输出交给接手 AI 分析。

#### 情况五：Docker 正常，但页面仍打不开

```bash
sudo ufw status verbose
ss -lntp | grep -E ':(22|8000|8012|8010|8011) '
curl -I http://127.0.0.1:8000/
curl -I http://127.0.0.1:8012/
docker compose -f /opt/standard-docs-system/deploy/docker-compose.yml \
  --env-file /opt/standard-docs-system/deploy/.env \
  logs --tail=200 frontend backend
docker compose -f /opt/datong-hub-offline-demo/deploy/docker-compose.yml \
  --env-file /opt/datong-hub-offline-demo/deploy/.env \
  logs --tail=200 frontend backend
```

本机接口正常而局域网页面异常时，重点检查服务器当前 LAN IP、UFW、天翼网关和客户端网段。

#### 最短启动命令速查

现场只需要快速恢复时，按顺序执行：

```bash
sudo systemctl enable --now containerd docker tailscaled

cd /opt/standard-docs-system/deploy
docker compose up -d --no-build --pull never

cd /opt/datong-hub-offline-demo/deploy
docker compose up -d --no-build --pull never

sleep 60
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' \
  | grep -E 'NAMES|dt-standard|datong-map'

curl -fsS http://127.0.0.1:8010/actuator/health && echo
curl -fsS http://127.0.0.1:8011/actuator/health && echo
```

---

## 6. 离线补丁包必须包含什么

建议补丁目录格式：

```text
PATCH_ID/
├── SHA256SUMS
├── standard-source-COMMIT.tar.gz       # 如更新标准化
├── datong-source-COMMIT.tar.gz         # 如更新大同
├── app-images-amd64.tar                # docker save 生成
├── RELEASE.md                          # 提交、变更、迁移、验证说明
└── compose/                            # 如 Compose 有变更，保留最终版本和 diff
```

应用镜像名称必须保持：

- `deploy-backend:latest`
- `deploy-frontend:latest`
- `datong-map-backend:latest`
- `datong-map-frontend:latest`

镜像架构必须为 `linux/amd64`。联网构建机导出示例：

```bash
docker image inspect IMAGE --format '{{.Architecture}} {{.Os}}'
docker save \
  deploy-backend:latest deploy-frontend:latest \
  datong-map-backend:latest datong-map-frontend:latest \
  -o app-images-amd64.tar
sha256sum *.tar *.tar.gz > SHA256SUMS
```

每个应用镜像建议带标签：

```text
org.opencontainers.image.revision=完整提交 SHA
```

---

## 7. 标准离线补丁流程

以下示例假定操作员已把补丁包复制到 `/opt/offline-inbox/PATCH_ID`。把占位符替换为本次真实值。

### 第 1 步：预检

```bash
export PATCH_ID=YYYYMMDD-COMMIT
export PATCH_DIR=/opt/offline-inbox/$PATCH_ID

cd "$PATCH_DIR"
sha256sum -c SHA256SUMS

docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
docker image inspect \
  deploy-backend:latest deploy-frontend:latest \
  datong-map-backend:latest datong-map-frontend:latest \
  --format '{{index .RepoTags 0}} {{.Id}} {{index .Config.Labels "org.opencontainers.image.revision"}}'
```

保存输出到补丁目录：

```bash
docker ps --no-trunc > "$PATCH_DIR/before-containers.txt"
docker image ls --digests > "$PATCH_DIR/before-images.txt"
```

### 第 2 步：备份配置和旧应用镜像

```bash
sudo mkdir -p "/opt/offline-backups/$PATCH_ID/config"
sudo chown -R datong:datong "/opt/offline-backups/$PATCH_ID"
export BACKUP_DIR="/opt/offline-backups/$PATCH_ID"

cp -a /opt/standard-docs-system/deploy/.env \
  "$BACKUP_DIR/config/standard.env"
cp -a /opt/standard-docs-system/deploy/docker-compose.yml \
  "$BACKUP_DIR/config/standard-compose.yml"
cp -a /opt/standard-docs-system/.deployment-commit \
  "$BACKUP_DIR/config/standard-commit"

cp -a /opt/datong-hub-offline-demo/deploy/.env \
  "$BACKUP_DIR/config/datong.env"
cp -a /opt/datong-hub-offline-demo/deploy/docker-compose.yml \
  "$BACKUP_DIR/config/datong-compose.yml"
cp -a /opt/datong-hub-offline-demo/.deployment-commit \
  "$BACKUP_DIR/config/datong-commit"
chmod 600 "$BACKUP_DIR/config/"*.env

for image in deploy-backend deploy-frontend datong-map-backend datong-map-frontend; do
  docker tag "$image:latest" "$image:rollback-$PATCH_ID"
done
```

### 第 3 步：一致性数据备份

只备份本次会更新的系统。如果两套都更新，则依次执行两套，减少同时停写时间。

#### 标准化完整备份

```bash
export B="/opt/offline-backups/$PATCH_ID/standard-data"
mkdir -p "$B"
cd /opt/standard-docs-system/deploy

docker compose stop frontend backend
docker compose exec -T mysql sh -c \
  'MYSQL_PWD="$MYSQL_PASSWORD" mysqldump --single-transaction --no-tablespaces --routines --triggers -u"$MYSQL_USER" "$MYSQL_DATABASE"' \
  | gzip > "$B/mysql.sql.gz"

docker compose stop minio
docker run --rm \
  -v deploy_minio-data:/data:ro \
  -v "$B:/backup" \
  alpine:latest tar -C /data -czf /backup/minio.tar.gz .
docker compose start minio

cp -a .env "$B/deploy.env"
chmod 600 "$B/deploy.env"
(cd "$B" && sha256sum mysql.sql.gz minio.tar.gz deploy.env > SHA256SUMS)

docker compose up -d --no-build --pull never backend frontend
```

#### 大同完整备份

```bash
export B="/opt/offline-backups/$PATCH_ID/datong-data"
mkdir -p "$B"
cd /opt/datong-hub-offline-demo/deploy

docker compose stop frontend backend
docker compose exec -T mysql sh -c \
  'MYSQL_PWD="$MYSQL_PASSWORD" mysqldump --single-transaction --no-tablespaces --routines --triggers -u"$MYSQL_USER" "$MYSQL_DATABASE"' \
  | gzip > "$B/mysql.sql.gz"

docker compose stop minio
docker run --rm \
  -v datong-map_minio-data:/data:ro \
  -v "$B:/backup" \
  alpine:latest tar -C /data -czf /backup/minio.tar.gz .
docker compose start minio

cp -a .env "$B/deploy.env"
chmod 600 "$B/deploy.env"
(cd "$B" && sha256sum mysql.sql.gz minio.tar.gz deploy.env > SHA256SUMS)

docker compose up -d --no-build --pull never backend frontend
```

确认两个备份目录内 `SHA256SUMS` 校验通过后再加载补丁。

### 第 4 步：加载新镜像

```bash
cd "$PATCH_DIR"
docker load -i app-images-amd64.tar

docker image inspect \
  deploy-backend:latest deploy-frontend:latest \
  datong-map-backend:latest datong-map-frontend:latest \
  --format '{{index .RepoTags 0}} {{.Architecture}} {{.Id}} {{index .Config.Labels "org.opencontainers.image.revision"}}'
```

核对：架构为 `amd64`，revision 等于本次提交。

### 第 5 步：更新服务器上的参考源码

先把旧源码目录完整打包，排除运行中的 `.env`：

```bash
tar -C /opt --exclude='standard-docs-system/deploy/.env' \
  -czf "$BACKUP_DIR/standard-source-before.tar.gz" standard-docs-system
tar -C /opt --exclude='datong-hub-offline-demo/deploy/.env' \
  -czf "$BACKUP_DIR/datong-source-before.tar.gz" datong-hub-offline-demo
```

解压新源码到临时目录并先检查：

```bash
rm -rf /tmp/standard-new /tmp/datong-new
mkdir -p /tmp/standard-new /tmp/datong-new

# 只更新其中一个系统时，仅执行对应命令
tar -xzf "$PATCH_DIR/standard-source-COMMIT.tar.gz" \
  -C /tmp/standard-new --strip-components=1
tar -xzf "$PATCH_DIR/datong-source-COMMIT.tar.gz" \
  -C /tmp/datong-new --strip-components=1

diff -u /opt/standard-docs-system/deploy/docker-compose.yml \
  /tmp/standard-new/deploy/docker-compose.yml || true
diff -u /opt/datong-hub-offline-demo/deploy/docker-compose.yml \
  /tmp/datong-new/deploy/docker-compose.yml || true
```

接手 AI 必须审查 Compose 差异并保持以下网络约束：

- 两个前端分别绑定 `0.0.0.0:8000`、`0.0.0.0:8012`。
- 后端、MySQL、Redis、MinIO、OnlyOffice 仍绑定 `127.0.0.1`。
- 保留原有卷名，不添加 `-v` 删除卷。
- 保留 `restart: unless-stopped`。

审查完成后同步源码，保留现有 `.env`：

```bash
rsync -a --delete \
  --exclude='deploy/.env' --exclude='.deployment-commit' \
  /tmp/standard-new/ /opt/standard-docs-system/

rsync -a --delete \
  --exclude='deploy/.env' --exclude='.deployment-commit' \
  /tmp/datong-new/ /opt/datong-hub-offline-demo/
```

根据本次提交写入记录：

```bash
printf '%s\n' 'STANDARD_FULL_COMMIT' \
  > /opt/standard-docs-system/.deployment-commit
printf '%s\n' 'DATONG_FULL_COMMIT' \
  > /opt/datong-hub-offline-demo/.deployment-commit
```

如果新源码 Compose 又恢复为未指定监听地址的写法，应把前端映射恢复成：

```yaml
# 标准化
- "0.0.0.0:${FRONTEND_PORT:-8000}:80"

# 大同
- "0.0.0.0:${FRONTEND_PORT:-8012}:80"
```

### 第 6 步：启动补丁镜像

标准化：

```bash
cd /opt/standard-docs-system/deploy
docker compose config --quiet
docker compose up -d --no-build --pull never
docker compose ps
```

大同：

```bash
cd /opt/datong-hub-offline-demo/deploy
docker compose config --quiet
docker compose up -d --no-build --pull never
docker compose ps
```

### 第 7 步：验证

```bash
for i in $(seq 1 30); do
  curl -fsS http://127.0.0.1:8010/actuator/health >/dev/null && \
  curl -fsS http://127.0.0.1:8011/actuator/health >/dev/null && break
  sleep 5
done

curl -fsS http://127.0.0.1:8000/ >/dev/null && echo standard_frontend_OK
curl -fsS http://127.0.0.1:8010/actuator/health && echo
curl -fsS http://127.0.0.1:8000/onlyoffice/web-apps/apps/api/documents/api.js >/dev/null \
  && echo onlyoffice_OK

curl -fsS http://127.0.0.1:8012/ >/dev/null && echo datong_frontend_OK
curl -fsS http://127.0.0.1:8011/actuator/health && echo

docker ps --format '{{.Names}}|{{.Status}}' \
  | grep -E '^(dt-standard|datong-map)' | sort
```

再用真实局域网设备打开：

- `http://192.168.1.7:8000`
- `http://192.168.1.7:8012`

业务验收至少覆盖：现有账号登录、标准化附件/OnlyOffice 预览、大同地图和图片访问。

查看数据库迁移：

```bash
docker logs --since=20m dt-standard-backend 2>&1 \
  | grep -Ei 'flyway|migration|error|exception' | tail -100
docker logs --since=20m datong-map-backend 2>&1 \
  | grep -Ei 'flyway|migration|error|exception' | tail -100
```

---

## 8. 应用镜像回滚

如果补丁后健康检查或业务验收失败，先保存日志：

```bash
docker logs --since=30m dt-standard-backend \
  > "/opt/offline-backups/$PATCH_ID/standard-backend-failed.log" 2>&1
docker logs --since=30m datong-map-backend \
  > "/opt/offline-backups/$PATCH_ID/datong-backend-failed.log" 2>&1
```

恢复旧应用镜像标签：

```bash
for image in deploy-backend deploy-frontend datong-map-backend datong-map-frontend; do
  docker tag "$image:rollback-$PATCH_ID" "$image:latest"
done
```

恢复旧源码和 Compose：

```bash
rm -rf /tmp/standard-rollback /tmp/datong-rollback
mkdir -p /tmp/standard-rollback /tmp/datong-rollback

tar -xzf "/opt/offline-backups/$PATCH_ID/standard-source-before.tar.gz" \
  -C /tmp/standard-rollback --strip-components=1
tar -xzf "/opt/offline-backups/$PATCH_ID/datong-source-before.tar.gz" \
  -C /tmp/datong-rollback --strip-components=1

rsync -a --delete --exclude='deploy/.env' \
  /tmp/standard-rollback/ /opt/standard-docs-system/
rsync -a --delete --exclude='deploy/.env' \
  /tmp/datong-rollback/ /opt/datong-hub-offline-demo/

cp -a "/opt/offline-backups/$PATCH_ID/config/standard-compose.yml" \
  /opt/standard-docs-system/deploy/docker-compose.yml
cp -a "/opt/offline-backups/$PATCH_ID/config/standard-commit" \
  /opt/standard-docs-system/.deployment-commit
cp -a "/opt/offline-backups/$PATCH_ID/config/datong-compose.yml" \
  /opt/datong-hub-offline-demo/deploy/docker-compose.yml
cp -a "/opt/offline-backups/$PATCH_ID/config/datong-commit" \
  /opt/datong-hub-offline-demo/.deployment-commit

cd /opt/standard-docs-system/deploy
docker compose up -d --no-build --pull never
cd /opt/datong-hub-offline-demo/deploy
docker compose up -d --no-build --pull never
```

如果补丁执行了不可逆数据库迁移，镜像回滚后仍可能出现数据结构不匹配；此时应停止前后端，根据本次补丁备份执行数据库恢复。恢复属于破坏性操作，先再次保留当前故障现场数据和日志。

---

## 9. 数据恢复原则

### 9.1 恢复前检查

```bash
export RESTORE_DIR=/opt/offline-backups/PATCH_ID/standard-data
cd "$RESTORE_DIR"
sha256sum -c SHA256SUMS
ls -lh mysql.sql.gz minio.tar.gz deploy.env
```

确认系统、备份目录和补丁编号匹配。标准化和大同的数据卷名不同，不要交叉使用。

### 9.2 恢复顺序

1. 停止目标系统 frontend/backend。
2. 再做一次当前故障状态备份。
3. 校验历史备份 SHA256。
4. 恢复 MySQL。
5. 停止 MinIO，清空对应 MinIO 数据卷内容，再解压备份。
6. 启动 MinIO、backend、frontend。
7. 对比关键表行数、Flyway 版本和业务文件读取。

数据恢复命令应由接手 AI 根据目标系统、备份文件和当时 Compose 配置逐条生成，不应把标准化卷名套到大同系统。

---

## 10. 已知维护缺口和建议

### 10.1 当前没有定时业务备份

审计时：

- `datong` 用户没有 crontab。
- `/opt/standard-docs-system/backups` 不存在。
- 大同默认备份目录 `/home/ubuntu/backups/datong` 不适合当前用户 `datong`。
- 现有迁移快照仍在，但它只代表初次迁移时间点。

### 10.2 大同自带备份脚本有两个离线适配点

文件：`/opt/datong-hub-offline-demo/deploy/backup.sh`、`restore.sh`

1. 默认 `BACKUP_ROOT=/home/ubuntu/backups/datong`，应设置为当前服务器路径，例如 `/opt/backups/datong`。
2. 脚本引用 `alpine:3.21`，当前离线镜像标签是 `alpine:latest`。启用定时备份前，应统一镜像标签或修改脚本并完成一次真实备份/恢复演练。

### 10.3 标准化自带 `./run.sh backup` 只备份 MySQL

附件实际保存在 `deploy_minio-data`。完整灾备必须同时保存 MySQL 和 MinIO，建议使用本手册第 7 节的一致性备份流程。

### 10.4 大同 MySQL 内存限额

`datong-map-mysql` 限额 512MiB，当前约使用 396MiB（77%）。整体服务器还有约 11–12GB 可用内存。业务并发增长或出现 MySQL OOM 时，可在验证后把 `mem_limit` 调到 `1g`，然后只重建该容器配置：

```bash
cd /opt/datong-hub-offline-demo/deploy
docker compose up -d --no-build --pull never mysql
docker compose ps mysql
```

修改前先备份 Compose，修改后观察 `docker stats`、MySQL 日志和业务接口。

### 10.5 IP 地址依赖 DHCP

Netplan 为 DHCP。天翼网关应确认 MAC 静态租约，否则未来 IP 变化后，用户应先在服务器本机运行：

```bash
ip -brief addr show enp2s0
ip route
```

然后更新访问地址及 `.env` 中与 IP 相关的公开入口配置。

### 10.6 单系统盘

Ubuntu 和 Docker 数据位于同一块 1TB 机械盘，SMART 当前健康，但累计通电时间较长。建议：

- 定期执行 `sudo smartctl -H -A /dev/sdb`；
- 每月执行 SMART 短自检；
- 数据备份复制到另一块物理盘或内网存储，不要只放在 `/dev/sdb`；
- 发现 `Reallocated_Sector_Ct`、`Current_Pending_Sector`、`Offline_Uncorrectable` 大于 0 时，立即迁出数据。

---

## 11. 常见故障定位

### 页面打不开

```bash
ip -brief addr
sudo ufw status verbose
ss -lntp | grep -E ':(8000|8012) '
docker ps --format '{{.Names}}|{{.Status}}|{{.Ports}}'
curl -I http://127.0.0.1:8000/
curl -I http://127.0.0.1:8012/
```

本机 curl 正常而局域网访问异常：优先检查 IP、UFW、网关/交换机和客户端是否在 `192.168.1.0/24`。

### 前端正常但登录或接口失败

```bash
curl -fsS http://127.0.0.1:8010/actuator/health
curl -fsS http://127.0.0.1:8011/actuator/health
docker logs --tail=300 dt-standard-backend
docker logs --tail=300 datong-map-backend
docker ps --format '{{.Names}}|{{.Status}}'
```

大同使用 HTTP 时检查：

```bash
grep -E '^(APP_PRODUCTION|AUTH_COOKIE_SECURE)=' \
  /opt/datong-hub-offline-demo/deploy/.env
```

当前预期都是 `false`。

### 数据库异常

```bash
docker logs --tail=300 dt-standard-mysql
docker logs --tail=300 datong-map-mysql
docker inspect -f '{{.Name}} restart={{.RestartCount}} oom={{.State.OOMKilled}}' \
  dt-standard-mysql datong-map-mysql
docker stats --no-stream dt-standard-mysql datong-map-mysql
```

### 附件或图片缺失

```bash
cd /opt/datong-hub-offline-demo/deploy
./check-storage-consistency.sh

docker logs --tail=300 dt-standard-minio
docker logs --tail=300 datong-map-minio
docker volume inspect deploy_minio-data datong-map_minio-data
```

### OnlyOffice 预览异常

```bash
docker ps --filter name=dt-standard-onlyoffice
docker logs --tail=300 dt-standard-onlyoffice
curl -fsS \
  http://127.0.0.1:8000/onlyoffice/web-apps/apps/api/documents/api.js \
  >/dev/null && echo OK
```

### 容器反复重启

```bash
for c in $(docker ps -a --format '{{.Names}}' | grep -E '^(dt-standard|datong-map)'); do
  docker inspect -f '{{.Name}} restart={{.RestartCount}} oom={{.State.OOMKilled}} exit={{.State.ExitCode}} error={{.State.Error}}' "$c"
done
```

先保存日志和 inspect 输出，再决定重启、回滚或恢复数据。

---

## 12. 每次维护结束必须记录

建议在 `/opt/maintenance-log/` 创建一次一目录：

```text
/opt/maintenance-log/YYYYMMDD-PATCH_ID/
├── operator.txt
├── purpose.md
├── before-containers.txt
├── before-images.txt
├── SHA256SUMS
├── commands.log
├── after-containers.txt
├── health-results.txt
└── rollback-result.txt     # 只有发生回滚时
```

至少记录：

- 操作时间和操作人；
- 两套 `.deployment-commit`；
- 补丁包 SHA256；
- 更新前后四个应用镜像 ID；
- 是否有 Flyway 迁移；
- 是否做过数据备份及其 SHA256；
- 容器健康、登录、附件/Office、地图/图片验证结果；
- 是否修改 `.env`、Compose、UFW 或 DHCP。

---

## 13. 当前状态摘要（供 AI 快速读取）

```yaml
host:
  hostname: datong
  os: Ubuntu 24.04.4 LTS
  arch: amd64
  cpu_cores: 2
  memory_gib: 14
  lan_ip: 192.168.1.7
  lan_ip_source: DHCP
  tailscale_ip: 100.123.188.49
  root_disk: /dev/sdb
  root_filesystem_gib: 914

standard:
  path: /opt/standard-docs-system
  compose_path: /opt/standard-docs-system/deploy
  env_path: /opt/standard-docs-system/deploy/.env
  commit: b8ff43c72964f6cb5ec9a98b4cce2eda6c218e49
  frontend: http://192.168.1.7:8000
  backend_health: http://127.0.0.1:8010/actuator/health
  compose_project: deploy
  volumes:
    mysql: deploy_mysql-data
    redis: deploy_redis-data
    minio: deploy_minio-data

datong:
  path: /opt/datong-hub-offline-demo
  compose_path: /opt/datong-hub-offline-demo/deploy
  env_path: /opt/datong-hub-offline-demo/deploy/.env
  commit: 26457fa7f3b7be79e93a7887c76bb772d28df2d5
  frontend: http://192.168.1.7:8012
  backend_health: http://127.0.0.1:8011/actuator/health
  compose_project: datong-map
  volumes:
    mysql: datong-map_mysql-data
    redis: datong-map_redis-data
    minio: datong-map_minio-data

offline_policy:
  github_available: false
  docker_hub_available: false
  update_method: clean source archive plus prebuilt amd64 image archive
  compose_start_flags: --no-build --pull never
  preserve_env: true
  preserve_volumes: true
```

此 YAML 可直接复制给新的 AI，并补充本次具体维护需求。
