# 随影 · RandoMov

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.10-0175C2?logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/State-Provider-7B61FF" alt="Provider">
  <img src="https://img.shields.io/badge/Storage-SQLite%20%2B%20SharedPreferences-0F7B0F" alt="Storage">
  <img src="https://img.shields.io/badge/Backend-Node.js%20%2B%20Socket.IO-111827" alt="Backend">
</p>

> 一个面向个人与多人观影场景的随机选片应用。  
> 维护本地片库、抓取豆瓣信息、单人随机抽片、多人房间同步抽奖，把“不知道看什么”这件事交给命运。

## 目录

- [功能特性](#功能特性)
- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [快速开始](#快速开始)
- [配置说明](#配置说明)
- [使用流程](#使用流程)
- [架构说明](#架构说明)
- [常用命令](#常用命令)
- [发布下载](#发布下载)
- [注意事项](#注意事项)

## 功能特性

- **本地片库管理**：支持手动添加、豆瓣单片链接抓取、豆列批量导入。
- **影片详情记录**：支持已看状态、分集进度、个人评分、个人短评、观影日期。
- **单人抽片**：从本地片库中快速随机抽取一部影片。
- **多人房间协作**：创建/加入房间，房主选片，所有成员实时同步状态。
- **幸运数字抽奖**：参与者提交幸运数字，共同影响抽奖种子。
- **抽奖历史**：本地保存单人抽奖和房间抽奖结果，支持分页查看与清空。
- **性能优化**：针对片库列表、详情页打开、冷启动首屏做过专项优化。

## 技术栈

| 层级 | 技术 |
| --- | --- |
| 客户端 | Flutter / Dart |
| 状态管理 | Provider (`ChangeNotifier`) |
| 路由 | `go_router` |
| 网络 | `dio`、`socket_io_client` |
| 本地存储 | `sqflite`、`shared_preferences` |
| 图片加载 | `cached_network_image` |
| HTML 解析 | `html` |
| 后端 | Node.js、Express、Socket.IO |

## 项目结构

```text
RandoMov/
├─ backend/                      # 房间服务与 Socket.IO 服务
│  ├─ package.json
│  └─ server.js
├─ random_movie/                 # Flutter 应用
│  ├─ lib/
│  │  ├─ config/                 # API、主题、环境配置
│  │  ├─ models/                 # Movie / Room / DrawRecord 等模型
│  │  ├─ providers/              # 业务状态管理
│  │  ├─ services/               # API、Socket、本地存储、豆瓣抓取
│  │  ├─ pages/                  # 片库 / 房间 / 观影历史 / 抽奖历史
│  │  ├─ widgets/                # 通用组件与业务组件
│  │  ├─ router/                 # 路由与底部导航
│  │  └─ icon/                   # 应用图标资源
│  ├─ android/
│  └─ pubspec.yaml
├─ CLAUDE.md
└─ README.md
```

## 快速开始

### 1. 环境要求

- Node.js `>= 18`
- 与 `random_movie/pubspec.yaml` 中 Dart `3.10.7` 兼容的 Flutter SDK
- Android Studio / VS Code（安装 Flutter 与 Dart 插件）
- Android 设备或模拟器

### 2. 启动后端

```bash
cd backend
npm install
npm run dev
```

默认监听：

- `http://localhost:3000`

健康检查：

```bash
curl http://localhost:3000/health
```

### 3. 配置客户端地址

编辑 `random_movie/lib/config/api_config.dart`：

```dart
static const String devBaseUrl = 'http://<你的IP>:3000';
static const String devSocketUrl = 'http://<你的IP>:3000';

static const String prodBaseUrl = 'http://<你的IP>:3000';
static const String prodSocketUrl = 'http://<你的IP>:3000';
```

Android 模拟器访问宿主机时，通常使用：

```text
10.0.2.2
```

### 4. 运行 Flutter 应用

```bash
cd random_movie
flutter pub get
flutter run
```

## 配置说明

### API 地址

客户端通过 `random_movie/lib/config/api_config.dart` 切换开发/生产环境地址：

- `devBaseUrl` / `devSocketUrl`
- `prodBaseUrl` / `prodSocketUrl`

生产环境地址会在 **Release / Product** 构建下自动生效。常用命令：

```bash
flutter run --release
flutter build apk --release
```

### Android 明文 HTTP

如果你的后端没有启用 HTTPS，Android 端需要允许明文流量。仓库中已经包含相关配置：

- `random_movie/android/app/src/main/AndroidManifest.xml`
- `random_movie/android/app/src/main/res/xml/network_security_config.xml`

如需更换服务器域名或 IP，请同步更新白名单配置。

## 使用流程

### 添加影片

1. 进入「片库」页面。
2. 点击右下角「添加」按钮。
3. 粘贴豆瓣单片链接或豆列链接，等待自动抓取。
4. 也可以直接手动录入影片信息。

### 单人抽奖

1. 进入「房间」页面。
2. 选择「我一个人」。
3. 从片库中勾选候选影片。
4. 开始抽奖并查看动画结果。

### 多人房间

1. 房主创建房间并分享 6 位房间码。
2. 其他成员输入房间码加入。
3. 房主从本地片库选择候选影片。
4. 所有人进入幸运数字阶段。
5. 服务端生成统一种子并广播抽奖动画数据。
6. 全员看到一致的抽奖结果。

### 记录管理

- **观影历史**：查看已标记看过的影片。
- **抽奖历史**：查看本地保存的单人/房间抽奖记录。

## 架构说明

### 数据存储

| 数据 | 存储位置 | 说明 |
| --- | --- | --- |
| 用户信息 | `SharedPreferences` | 保存 `userId`、`userName` 等轻量配置 |
| 影片库 | `SQLite` | 保存影片、分集、观影状态、评分、短评等 |
| 抽奖历史 | `SQLite` | 保存单人/房间抽奖记录 |
| 房间状态 | 后端内存 | 房间成员、候选片单、幸运数字、抽奖结果 |

### 影片数据来源

- 单片信息通过 `MovieScraperService` 直接请求并解析豆瓣页面。
- 豆列通过抓取豆列 HTML 并解析条目列表导入。
- 海报加载使用 `CachedNetworkImage`，并携带豆瓣 `Referer` 请求头。
- **当前项目不依赖 WMDB 或其他第三方电影 API。**

### 客户端与服务端通信

#### HTTP 接口

- `GET /health`
- `POST /api/rooms`
- `GET /api/rooms?code=<房间码>`

#### Socket.IO 事件

客户端发送：

- `join-room`
- `leave-room`
- `update-room-movies`
- `submit-lucky-number`
- `start-draw`
- `reset-room`

服务端广播：

- `room-updated`
- `draw-started`
- `draw-result`
- `room-reset`
- `room-closed`
- `error`

### 设计约束

- 房间服务当前是**纯内存实现**，服务重启后房间数据会丢失。
- 10 分钟无活动的房间会被自动清理。
- 抽奖动画依赖统一 `seed`，保证所有客户端动画过程一致。

## 常用命令

### Flutter

```bash
cd random_movie

flutter pub get
flutter run
flutter run -d <device-id>
flutter analyze
flutter test
flutter build apk
```

### Backend

```bash
cd backend

npm install
npm run dev
npm start
```

## 发布下载

- GitHub Releases：<https://github.com/ShareWinter/RandoMov/releases>

构建 APK：

```bash
cd random_movie
flutter build apk --release
```

输出目录：

```text
random_movie/build/app/outputs/flutter-apk/
```

## 注意事项

- 如果客户端连不上后端，先检查 `ApiConfig` 中的地址是否可达。
- Android 模拟器连接本机后端时，不要直接使用 `localhost`。
- 如果你修改了后端域名或端口，记得同步检查 Android 网络安全配置。
- 当前仓库未附带单独的 `LICENSE` 文件，如需开源分发请自行补充协议声明。
