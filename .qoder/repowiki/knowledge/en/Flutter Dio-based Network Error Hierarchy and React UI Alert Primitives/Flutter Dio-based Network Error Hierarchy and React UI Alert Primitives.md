---
kind: error_handling
name: Flutter Dio-based Network Error Hierarchy and React UI Alert Primitives
category: error_handling
scope:
    - '**'
source_files:
    - lib/app/core/logic/repository/repo_network_helper.dart
    - lib/app/core/logic/repository/error.dart
    - lib/app/core/logic/repository/app_exception.dart
    - lib/app/core/logic/data_state/data_state.dart
    - lib/app/features/authentication/repository/auth_repository.dart
    - lib/app/features/courses/repository/course_repository.dart
    - lib/main.dart
    - src/app/components/ui/alert.tsx
    - src/app/components/ui/alert-dialog.tsx
---

## Overview

This repository is a multi-platform LMS with two distinct codebases sharing the same error-handling philosophy: a Flutter app (Dart) that centralizes network errors through a typed exception hierarchy, and a separate React web dashboard that provides shadcn/ui alert primitives for user-facing error display. There is no shared error library between them.

## Flutter side — centralized Dio → typed exception pipeline

### Core architecture

- **`lib/app/core/logic/repository/repo_network_helper.dart`** defines `RepoNetworkHelper`, a mixin every repository mixes in (`AuthRepository`, `CourseRepository`). It wraps a `Dio` client with connect/send/receive timeouts (20s/30s), an optional token-refresh interceptor (401 retry via `RepoNetworkConfig.refreshToken`), offline-mode checks, request caching, and FormData serialization helpers.
- Every HTTP method (`post`, `getRequest`, `put`, `deleteRequest`, `patch`) catches `catch (e)` and calls `handelException(e)` then `rethrow`, so callers always see a typed application-level exception rather than raw `DioException`s or generic Dart exceptions.
- Offline behavior: when `isOffline` is true, `performOfflineRequest` throws a plain `Exception("No Internet")` for cached reads or returns `null` for queued POSTs; this is caught by `handelException` which maps `SocketException` to `InternetException`.

### Exception hierarchy (`lib/app/core/logic/repository/app_exception.dart`)

All errors are subclasses of `AppException`, which carries a `_message` and a `_prefix` (used as a title). The hierarchy:

| Exception | When thrown |
|---|---|
| `FetchDataException` | Generic network / unknown Dio errors |
| `InternetException` | `SocketException` or connection errors |
| `BadRequestException` | HTTP 400 |
| `UnauthorizedException` | HTTP 401 / 403 |
| `NotFoundException` | HTTP 404 |
| `InvalidInputException` | HTTP 422 (validation errors parsed from `errors` Map/List) |
| `TooManyRequestException` | HTTP 429 |
| `InvalidResponseException` | Reserved for malformed responses |
| `AppException` | Catch-all (timeouts, cancellation, bad certificate, file too large) |

### Error normalization (`lib/app/core/logic/repository/error.dart`)

`handelException(e)` is the single conversion point:
- Non-`DioException` paths: `SocketException` → `InternetException`; anything else → `FetchDataException`.
- `DioExceptionType.badResponse` branches on `statusCode` to pick the right subclass.
- For 422 validation errors it flattens nested `Map<String, List>` or `List` payloads into newline-separated strings.
- A helper `_messageFrom(dynamic data)` safely extracts a message from server responses that may be a `String`, `List`, or `Map` — avoiding crashes when the server returns non-JSON error bodies.

### Data-state wrapper (`lib/app/core/logic/data_state/data_state.dart`)

ViewModels wrap results in `DataState<T>` with states `idle`, `loading`, `data`, `error`. This is the ViewModel-side contract for surfacing success/failure to widgets. It stores a plain `String? error` (not the exception object).

### User-facing error presentation

- The root widget wraps everything in `flutter_styled_toast`'s `StyledToast`, so transient errors can be shown as localized toast messages.
- `main.dart` uses `unawaited(FileCacheViewModel.clearAllViewing())` at startup to best-effort clean up leftover temp files from crashed previous runs — a soft failure pattern where startup does not abort on cleanup errors.

### Authentication-specific flow

`AuthRepository.validateToken` attempts a GET to validate the current session; if it fails it falls back to `auth/auto-login` using the stored `autoLoginToken`, and throws `UnauthorizedException` when neither path succeeds. The `RepoNetworkHelper` Dio interceptor also auto-retries once on 401 by calling `config.refreshToken` before re-propagating the original error.

## React web side — static UI components only

The `src/` tree is a standalone React + Tailwind dashboard. It contains no business logic, API calls, or runtime error handling. Instead it ships shadcn/ui primitives that *could* render errors:

- `src/app/components/ui/alert.tsx` — `<Alert>` with `default` / `destructive` variants.
- `src/app/components/ui/alert-dialog.tsx` — Radix-powered `<AlertDialog>` with overlay, trigger, content, header/footer, action/cancel.

These are presentational building blocks; they are not wired to any global error handler in the codebase examined.

## Conventions observed

1. **Never swallow network errors silently.** Every `repo_network_helper` HTTP method logs via `handelException` and then `rethrows`; callers must handle the typed exception.
2. **Throw domain exceptions, not framework exceptions.** Callers catch `AppException` subclasses; raw `DioException` or `SocketException` never escape the repository layer.
3. **User-facing titles come from the exception prefix.** `AppException.title` maps directly to user-visible labels like "Connection error", "Unauthorized", "Invalid Request".
4. **Offline-first branch:** repositories check `isOffline` before touching the network and throw a consistent `Exception("No Internet")` that gets normalized.
5. **Validation errors are flattened.** 422 responses with nested field errors are collapsed into a single newline-delimited string passed to `InvalidInputException`.
6. **React side has no runtime error handling yet.** The dashboard currently renders static mock data; error UI exists only as unconnected shadcn/ui components.
7. **No global Flutter error boundary.** There is no `runZoned` / `FlutterError.onError` / `ErrorWidget.builder` configured in `main.dart`; unhandled exceptions will bubble to the platform crash reporter.