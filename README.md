# RelaySend

基于 LocalSend 的二次开发版，目标是让 Android、Windows、Linux 等设备在同一个
WebRTC 信令服务器下互相发现和传输。

## 核心能力

- 内网优先：同一 NAT 或内网内的设备通过本机地址优先建立 WebRTC P2P 连接。
- 公网中继兜底：跨网络无法直连时，通过 STUN/TURN 继续完成传输。
- 设备在线状态：客户端连接信令服务器后，其他设备可以看到在线设备列表。
- 剪切板读取：Android 客户端可以在应用内粘贴当前剪切板内容并发送。
- 临时网页分享：服务端内置 `/share` 页面，浏览器可直接分享文本或文件，
  无需安装客户端。
- 轻量服务器：Rust 编写的 WebSocket 信令服务器，客户端间传输不经过服务器；
  临时网页分享文件会短期保存到服务器并自动清理。

## 产物说明

- `app-arm64-v8a-release.apk`：64 位 ARM Android 手机和平板。
- `app-armeabi-v7a-release.apk`：32 位 ARM Android 设备。
- `app-x86_64-release.apk`：x86_64 Android 模拟器或设备。
- `relay-server-linux-x86_64`：Linux x86_64 信令服务器，直接运行即可。
- `build_relay_artifacts.yml`：GitHub Actions 工作流，可在 GitHub 上自动构建
  Android、Windows portable 和 Linux relay server 版本。
- `relay.patch`：基于 `af3aad33c965defc39ecff8d9a4396a851ce3cc1` 的改动补丁。

## 服务器部署

以 `ROOM_MODE=ip` 启动时，服务器按客户端来源 IP 分组，适合内网优先场景；
使用 `ROOM_MODE=global` 时，所有客户端进入同一个在线列表。

```bash
chmod +x relay-server-linux-x86_64
ROOM_MODE=ip \
SERVER_IP=0.0.0.0 \
SERVER_PORT=18080 \
MAX_CONNECTIONS_PER_IP=20 \
./relay-server-linux-x86_64
```

客户端信令地址为 `ws://服务器IP:18080/v1/ws`。生产环境请放在 Nginx 或 Caddy
后面启用 TLS，并确保透传 `X-Forwarded-For`。

如果客户端需要跨 NAT 传输，Docker Compose 已内置 coturn。部署后打开防火墙的
`3478/tcp`、`3478/udp` 和 `49160-49200/udp`，然后在客户端配置 STUN/TURN。

### Docker 部署

服务器上可以一条命令下载需要的部署文件并启动：

```bash
curl -fsSL https://raw.githubusercontent.com/Steve0723/relaysend/main/deploy.sh -o deploy.sh
bash deploy.sh
```

脚本会在当前目录创建 `relaysend-server/`，下载 `Dockerfile`、
`docker-compose.yml` 和 `relay.patch`，自动生成包含随机 TURN 密码的 `.env`，
然后执行 `docker compose up -d --build`。部署目录可通过环境变量
`RELAYSEND_DEPLOY_DIR` 修改，TURN 用户名/密码可通过 `TURN_USER` 和
`TURN_PASSWORD` 预先指定。

在本仓库根目录直接构建镜像并启动，构建时会自动拉取 LocalSend 基线并应用
`relay.patch`：

```bash
docker build -t relaysend-server .
docker run -d --name relaysend-server \
  -p 18080:18080 \
  -e ROOM_MODE=global \
  -e MAX_CONNECTIONS_PER_IP=20 \
  -e MAX_REQUESTS_PER_IP_PER_HOUR=1000 \
  -v relaysend-share-data:/data/shares \
  -e SHARE_DATA_DIR=/data/shares \
  relaysend-server
```

也可以使用 Docker Compose：

```bash
docker compose up -d --build
```

Docker Compose 会同时启动 RelaySend 信令服务和 coturn。首次使用建议先检查
生成的 `.env`，确认 TURN 用户和密码没有被泄露。

| TURN 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `TURN_REALM` | `relay.example.com` | coturn realm，客户端配置不需要填写 |
| `TURN_USER` | `relay` | TURN 用户名 |
| `TURN_PASSWORD` | `change-me-before-use` | TURN 密码，必须改成强密码 |

可选环境变量：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `ROOM_MODE` | `global` | `ip` 按来源 IP 分组，`global` 使用同一个大厅 |
| `SERVER_PORT` | `18080` | 监听端口 |
| `SHARE_TTL_HOURS` | `24` | 临时分享链接保留小时数 |
| `MIN_SHARE_TTL_MINUTES` | `5` | 临时分享链接最短有效时间（分钟） |
| `MAX_SHARE_TTL_HOURS` | `168` | 临时分享链接最长有效时间（小时） |
| `MAX_SHARE_SIZE_MB` | `100` | 单次临时分享的最大总大小（MB） |
| `MAX_SHARE_FILES` | `20` | 单次临时分享的最大文件数 |
| `SHARE_DATA_DIR` | `./share-data` | 临时分享文件存储目录 |
| `SHARE_AUTH_USERS` | 空 | 分享登录账号，多个用逗号分隔，格式 `user1:pass1,user2:pass2` |
| `SHARE_AUTH_USERNAME` | `admin` | 单账号模式分享用户名 |
| `SHARE_AUTH_PASSWORD` | 随机生成 | 单账号模式分享密码 |

### Nginx 反向代理示例

假设域名是 `relay.example.com`，本地 RelaySend 服务监听 `127.0.0.1:18080`。
建议只让代理端口对外，不要直接暴露 18080 端口。

```nginx
server {
    listen 80;
    server_name relay.example.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name relay.example.com;

    ssl_certificate     /etc/letsencrypt/live/relay.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/relay.example.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:18080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Authorization $http_authorization;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
```

配置完成后，客户端地址填：

```text
wss://relay.example.com/v1/ws
```

公网传输需要在客户端“设置 -> 网络 -> STUN/TURN server”中配置：

```text
stun:relay.example.com:3478
turn:用户名:密码@relay.example.com:3478?transport=tcp
```

如果没有域名，也可以直接使用服务器公网 IP，并把信令地址写成
`wss://服务器IP/v1/ws`。

## 临时网页分享

不需要安装 RelaySend 的设备可以打开：

```text
http://服务器IP:18080/share
```

分享者需要先登录（HTTP Basic Auth），账号由服务器管理员预置，不开放注册。
`deploy.sh` 会在服务器本地 `.env` 中生成 `SHARE_AUTH_USERNAME` 和
`SHARE_AUTH_PASSWORD`（默认用户名 `admin`）；用 `SHARE_AUTH_USERS` 可以一次配置
多个账号。收到 `/s/<id>` 链接的接收者不需要登录。粘贴文本或选择文件后提交，
会生成 `/s/<id>` 链接。临时链接默认保留 24 小时，服务端会自动清理，
文件不会永久保存。

使用 HTTPS 域名时，网页分享地址为：

```text
https://relay.example.com/share
```

## Android 安装

安装 APK 后，在“设置 -> 网络 -> Relay server”中填写信令服务器地址，例如：

```text
ws://123.45.67.89:18080/v1/ws
```

Windows 客户端同样在“设置 -> 网络 -> Relay server”中配置信令服务器，在
“STUN/TURN server”中配置跨 NAT 传输地址。

设备需要和服务器保持 WebSocket 连接才能显示在线状态和参与信令交换。

## Windows 构建

本目录中的 Linux 环境无法直接产出 Windows portable 包。只要把本仓库推到
GitHub 并触发 `build_relay_artifacts.yml`，Actions 会自动构建：

```text
RelaySend-<version>-windows-x86-64.zip
```

也可以在 Windows 机器上使用 Flutter 3.41.9 和 Rust 执行：

```bash
git clone https://github.com/LocalSend/LocalSend.git
cd LocalSend
git checkout af3aad33c965defc39ecff8d9a4396a851ce3cc1
git apply ../relay.patch
cd app
flutter pub get
flutter build windows
```

## SHA256

校验值见 `SHA256SUMS`。
