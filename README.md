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
SERVER_PORT=3000 \
MAX_CONNECTIONS_PER_IP=20 \
./relay-server-linux-x86_64
```

客户端信令地址为 `ws://服务器IP:3000/v1/ws`。生产环境请放在 Nginx 或 Caddy
后面启用 TLS，并确保透传 `X-Forwarded-For`。

如果客户端需要跨 NAT 传输，还需要配置公网 TURN 服务，并在客户端 ICE server
中加入 STUN/TURN 地址。

### Docker 部署

在本仓库根目录直接构建镜像并启动，构建时会自动拉取 LocalSend 基线并应用
`relay.patch`：

```bash
docker build -t relaysend-server .
docker run -d --name relaysend-server \
  -p 3000:3000 \
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

可选环境变量：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `ROOM_MODE` | `global` | `ip` 按来源 IP 分组，`global` 使用同一个大厅 |
| `SHARE_TTL_HOURS` | `24` | 临时分享链接保留小时数 |
| `MAX_SHARE_SIZE_MB` | `100` | 单次临时分享的最大总大小（MB） |
| `MAX_SHARE_FILES` | `20` | 单次临时分享的最大文件数 |
| `SHARE_DATA_DIR` | `./share-data` | 临时分享文件存储目录 |

### Nginx 反向代理示例

假设域名是 `relay.example.com`，本地 RelaySend 服务监听 `127.0.0.1:3000`。
建议只让代理端口对外，不要直接暴露 3000 端口。

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
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
```

配置完成后，客户端地址填：

```text
wss://relay.example.com/v1/ws
```

## 临时网页分享

不需要安装 RelaySend 的设备可以打开：

```text
http://服务器IP:3000/share
```

粘贴文本或选择文件后提交，会生成 `/s/<id>` 链接。临时链接默认保留 24 小时，
服务端会自动清理，文件不会永久保存。

使用 HTTPS 域名时，网页分享地址为：

```text
https://relay.example.com/share
```

## Android 安装

安装 APK 后，在“设置 -> 网络 -> Relay server”中填写信令服务器地址，例如：

```text
ws://123.45.67.89:3000/v1/ws
```

Windows 客户端同样在“设置 -> 网络 -> Relay server”中配置。

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
