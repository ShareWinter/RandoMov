# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**随影 (RandoMov)** — A multi-user collaborative movie selection app. Users maintain a local movie library, join/create rooms, and perform a synchronized lottery draw.

The Flutter project lives in the `random_movie/` subdirectory. All Flutter commands must be run from there.

## Development Commands

```bash
cd random_movie

# Run app (debug)
flutter run

# Run on specific device
flutter run -d <device-id>

# Install dependencies
flutter pub get

# Analyze / lint
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/some_test.dart

# Build Android APK
flutter build apk

# Build release APK (production env)
flutter build apk --dart-define=dart.vm.product=true
```

## Architecture

### Layer Responsibilities

| Layer | Location | Role |
|---|---|---|
| Config | `lib/config/` | Environment URLs, theme tokens |
| Models | `lib/models/` | Pure data objects with `fromJson`/`toJson` |
| Services | `lib/services/` | HTTP, Socket, local storage, scraping |
| Providers | `lib/providers/` | Business state + error/loading; expose methods to UI |
| Pages | `lib/pages/` | Route-level screens, no direct network/storage calls |
| Widgets | `lib/widgets/` | Reusable UI components |
| Router | `lib/router/app_router.dart` | go_router config + `HomeShell` (3-tab bottom nav) |

### Data Sources — Single Source of Truth

- **Local movie library**: `StorageService` (SharedPreferences) is the only source. Never synced to backend.
- **Room state**: Server-pushed `room-updated` Socket event is authoritative.
- **Draw history**: Backend, queried by `roomCode`.

### Startup Sequence

`main()` → `StorageService.init()` → `runApp()` → `UserProvider.getOrCreateUser()`

`StorageService` is a singleton; call `StorageService()` to get the instance.

### Movie Scraping (Frontend Only)

- **Single movie** (douban `/subject/{id}/` URL): `MovieScraperService` directly请求豆瓣页面并解析结构化数据，不走第三方电影接口，也不走后端代理
- **Doulist** (douban `/doulist/{id}/` URL): Dio fetch HTML → parse with `html` package → `document.querySelectorAll('.doulist-item')`
- **Poster images**: `CachedNetworkImage` with `httpHeaders` from `ApiConfig.imageHeaders` (sets `Referer: https://movie.douban.com/`) to bypass hotlink protection

### Backend API (Minimal — Rooms + History Only)

| Method | Endpoint | Purpose |
|---|---|---|
| POST | `/api/rooms` | Create room |
| GET | `/api/rooms?code=` | Validate & fetch initial room |
| GET | `/api/history?roomCode=&limit=&skip=` | Paginated draw history |

Socket events the client **emits**: `join-room`, `leave-room`, `update-user-movies`, `start-draw`, `reset-room`

Socket events the server **pushes**: `room-updated` (authoritative state), `draw-started` (seed + candidates), `draw-result`, `room-reset`, `room-closed`, `kicked`, `error`

### Environment Switching

`lib/config/api_config.dart` uses `bool.fromEnvironment('dart.vm.product')` to switch between dev (`localhost:3000/3001`) and production URLs. Pass `--dart-define=dart.vm.product=true` for production builds.

## Key Constraints

- MVP uses `provider` (ChangeNotifier), not Riverpod/BLoC — keep it that way until explicitly decided otherwise.
- SharedPreferences keys are fixed: `movie_app_user_id`, `movie_app_user_name`, `movie_app_local_movies`.
- `userId` is generated once and never changes; only `userName` is mutable.
- SharedPreferences stores movies as a JSON array string — suitable for hundreds of entries (MVP scope). Upgrade path: Hive/Isar.
- All pages must handle: empty state, loading state, error state + retry.
- Draw animation uses a deterministic `seed` from `draw-started` so all clients show identical animations.

## UI / Theme

`AppTheme` in `lib/config/app_theme.dart` provides:
- Dark theme (default): background `#1A1A2E`, accent red `#E94560`, glassmorphism surfaces
- Light theme: background `#F5F6FA`, same accent
- `GlassDecoration` helpers for card/sheet glass effect
- Spacing constants: `spacingXSmall(4)` → `spacingXLarge(32)`
- Radius constants: `radiusSmall(8)` → `radiusXLarge(24)`
- All page transitions use `CupertinoPageTransitionsBuilder` on Android/iOS/macOS

Use `AppTheme` tokens instead of hardcoded colors/values.
