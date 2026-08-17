# LocalSend Relay

基于 LocalSend 的二次开发版，目标是让 Android、Windows、Linux 等设备在同一个
WebRTC 信令服务器下互相发现和传输。

## 核心能力

- 内网优先：同一 NAT 或内网内的设备通过本机地址优先建立 WebRTC P2P 连接。
- 公网中继兜底：跨网络无法直连时，通过 STUN/TURN 继续完成传输。
- 设备在线状态：客户端连接信令服务器后，其他设备可以看到在线设备列表。
- 剪切板读取：Android 客户端可以在应用内粘贴当前剪切板内容并发送。
- 轻量服务器：Rust 编写的 WebSocket 信令服务器，不承担文件转发，适合 VPS 部署。

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

## Android 安装

安装 APK 后，在设置中填写信令服务器地址，例如：

```text
ws://123.45.67.89:3000/v1/ws
```

设备需要和服务器保持 WebSocket 连接才能显示在线状态和参与信令交换。

## Windows 构建

本目录中的 Linux 环境无法直接产出 Windows portable 包。只要把本仓库推到
GitHub 并触发 `build_relay_artifacts.yml`，Actions 会自动构建：

```text
LocalSend-<version>-windows-x86-64.zip
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
