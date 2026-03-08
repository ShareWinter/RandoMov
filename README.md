# 随影 (RandoMov)

> 多人协作选片抽奖应用 — 不知道看什么？让命运来决定！

## 功能概览

- **本地片库** — 通过豆瓣链接或手动方式添加影片，管理个人观影库
- **单人抽奖** — 从片库中随机抽取一部影片
- **多人房间** — 创建/加入房间，房主选片，所有人同步观看抽奖动画
- **幸运数字** — 每位参与者提交幸运数字，影响抽奖结果的种子
- **观影记录** — 追踪个人观影历史和房间抽奖历史

## 技术栈

| 层级 | 技术 |
|------|------|
| 移动端 | Flutter 3.10+ / Dart |
| 状态管理 | Provider (ChangeNotifier) |
| 路由 | go_router |
| 后端 | Node.js + Express + Socket.IO |
| 本地存储 | SharedPreferences |
| 网络请求 | Dio (HTTP) + socket_io_client (WebSocket) |

## 项目结构

```
RandoMov/
├── backend/                    # Node.js 后端服务
│   ├── server.js              # 服务器入口（房间管理 + Socket 事件）
│   └── package.json
├── random_movie/              # Flutter 移动应用
│   ├── lib/
│   │   ├── config/            # API 地址、主题配置
│   │   ├── models/            # 数据模型（Movie, Room, Participant...）
│   │   ├── services/          # HTTP、Socket、本地存储、豆瓣爬取
│   │   ├── providers/         # 业务状态管理
│   │   ├── pages/             # 页面（片库、房间、观影历史）
│   │   ├── widgets/           # 可复用 UI 组件
│   │   ├── router/            # go_router 路由配置
│   │   └── icon/              # 应用图标
│   ├── android/               # Android 原生配置
│   └── pubspec.yaml
└── CLAUDE.md                  # AI 开发指南
```

## 快速开始

### 环境要求

- **Flutter** >= 3.10（含 Dart SDK）
- **Node.js** >= 18
- **Android Studio** 或 **VS Code**（含 Flutter 插件）
- Android 设备/模拟器（API 28+）

### 1. 启动后端

```bash
cd backend
npm install
npm run dev
```

后端默认运行在 `http://localhost:3000`，可通过环境变量 `PORT` 修改。

### 2. 配置 API 地址

编辑 `random_movie/lib/config/api_config.dart`，将 `devBaseUrl` 和 `devSocketUrl` 设为后端实际地址：

```dart
static const String devBaseUrl = 'http://<你的IP>:3000';
static const String devSocketUrl = 'http://<你的IP>:3000';
```

> 模拟器访问本机后端请使用 `10.0.2.2`（Android 模拟器）。

### 3. 运行 Flutter 应用

```bash
cd random_movie
flutter pub get
flutter run
```

## 自行部署

### 后端部署

后端为无状态内存服务（无数据库依赖），部署非常轻量：

```bash
# 1. 克隆仓库并安装依赖
cd backend
npm install --production

# 2. 启动服务（推荐使用 pm2）
npm install -g pm2
pm2 start server.js --name randomov

# 3. 验证服务
curl http://localhost:3000/health
```

**环境变量：**

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `PORT` | `3000` | 服务端口 |

> 注意：房间数据存储在内存中，服务重启后房间会丢失。10 分钟无活动的房间会被自动清理。

### 生产环境构建 APK

```bash
cd random_movie

# 1. 修改 api_config.dart 中的生产环境地址
#    prodBaseUrl / prodSocketUrl

# 2. 构建 Release APK
flutter build apk --dart-define=dart.vm.product=true

# 产物位于 build/app/outputs/flutter-apk/app-release.apk
```

### 网络安全配置

Release APK 需要允许 HTTP 明文流量（如果后端未启用 HTTPS）。项目已在以下文件中配置：

- `android/app/src/main/AndroidManifest.xml` — `usesCleartextTraffic="true"`
- `android/app/src/main/res/xml/network_security_config.xml` — 允许的域名列表

如需修改允许的后端域名，编辑 `network_security_config.xml`：

```xml
<domain-config cleartextTrafficPermitted="true">
    <domain includeSubdomains="true">你的服务器IP或域名</domain>
</domain-config>
```

## 使用流程

### 添加影片

1. 进入「片库」页面，点击右下角「添加」按钮
2. 粘贴豆瓣电影链接（单部影片 或 豆列），自动抓取影片信息
3. 也可选择手动输入影片名称

### 单人抽奖

1. 进入「房间」页面，选择「我一个人」
2. 从片库中勾选候选影片
3. 点击「开始抽奖」，观看动画揭晓结果

### 多人房间

1. **房主**：选择「创建房间」，获得 6 位房间码，分享给朋友
2. **成员**：选择「加入房间」，输入房间码加入
3. **房主选片**：房主从本地片库中选择候选影片，成员实时查看
4. **开始抽奖**：房主点击「准备抽奖」，所有人进入幸运数字提交阶段
5. **输入幸运数字**：5 秒内输入 1-99 的数字（超时自动分配）
6. **同步动画**：所有客户端基于相同种子播放一致的抽奖动画
7. **查看结果**：揭晓抽中的影片，房主可选择「再来一次」

## 常用命令

```bash
# Flutter 相关（在 random_movie/ 目录下执行）
flutter pub get          # 安装依赖
flutter run              # 调试运行
flutter run -d <设备ID>   # 指定设备运行
flutter analyze          # 代码静态分析
flutter test             # 运行测试
flutter build apk        # 构建 Debug APK

# 后端相关（在 backend/ 目录下执行）
npm install              # 安装依赖
npm run dev              # 开发模式（文件监听）
npm start                # 生产模式
```

## 架构说明

### 数据源

| 数据 | 存储位置 | 说明 |
|------|----------|------|
| 影片库 | 客户端 SharedPreferences | 纯本地，不同步到后端 |
| 用户信息 | 客户端 SharedPreferences | userId 一次生成不可变，userName 可修改 |
| 房间状态 | 后端内存 | 服务端权威，通过 Socket 实时推送 |
| 抽奖历史 | 客户端本地 | 每次抽奖结束后保存到本地 |

### 通信协议

- **REST API**：房间创建、验证（POST/GET `/api/rooms`）
- **WebSocket**：房间内实时状态同步（Socket.IO）
- **抽奖同步**：服务端广播相同 seed，各客户端用确定性算法计算结果，保证动画一致

## License

MIT
