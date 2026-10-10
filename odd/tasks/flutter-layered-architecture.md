# flutter-layered-architecture

## Objective

Replace the Flutter counter scaffold with the layered MVVM architecture described in `CONTEXT.md` section 18, so every later feature has a place to live.

## Problem and why

`lib/` only holds `main.dart` (counter demo) and `supabase_config.dart`. There is no local database, no sync path, no state management and no folder convention. AgroApp is offline-first, so the data layer must exist before any screen is built.

## Scope

- Dependencies: `drift`, `drift_flutter`, `provider`, `uuid`, `connectivity_plus`; dev `drift_dev`, `build_runner`.
- `lib/utils/result.dart`: `Result<T>`.
- `lib/domain/models/`: `SyncStatus`, `OutboxRecord`, `SyncSummary`.
- `lib/data/local/`: Drift `AppDatabase` with a generic `outbox` table and an `app_settings` key-value table.
- `lib/data/services/`: `SupabaseSyncService` (calls the `sync_batch` RPC), `ConnectivityService`.
- `lib/data/repositories/`: `OutboxRepository` (reads/writes Drift only).
- `lib/data/sync/`: `SyncEngine`.
- `lib/ui/`: `core/` theme and shared widgets, `features/home` (view model + view with the three main actions and a sync indicator), placeholder views for `activity_log`, `incident_report`, `harvest`.
- `lib/app.dart`, `lib/config/`, dependency registration, slim `main.dart`.

## Out of scope

Domain tables (activities, incidents, harvests), auth/login, photos, catalogs, reminders, routing package, real feature forms.

## Constraints

- Repositories never touch Supabase; only `SyncEngine` uploads, through `SupabaseSyncService`.
- Record ids are client-generated UUIDs; outbox row shape matches `supabase/migrations/09_sync_rpc.sql` (`table`, `id`, `payload`, `client_created_at`).
- `sync_status`: `pending → syncing → synced | error`. A failed record never aborts the batch.
- Code and identifiers in English; farmer-facing UI copy in neutral Spanish as defined in `CONTEXT.md` section 6.
- No view model imports `supabase_flutter`.

## Tasks

- [ ] **T1 — Data layer and sync core** (route: delegated; trigger: 2+ non-trivial files)
  - Acceptance: enqueueing a record stores it as `pending`; `SyncEngine.syncPending()` marks returned ids `synced`, failed ids `error` with message and incremented attempts; network failure leaves records retryable; offline is a no-op.
  - Checks: `dart run build_runner build`, `flutter analyze`, `flutter test test/data`.
- [ ] **T2 — UI shell and dependency wiring** (route: delegated; same writer)
  - Acceptance: app boots into Home with the three main actions and "Mis asistencias"; sync indicator shows pending count; each action opens its placeholder view; counter demo removed.
  - Checks: `flutter analyze`, `flutter test`.

## Delivery

Strategy: `ask-on-risk`. Forecast: ~700 authored lines (generated `*.g.dart` excluded). Branch: `feat/flutter-layered-architecture`, branch point `10023a8`.

## Progress

- [x] T1 done — commit `0587282` (made by the repo owner while the writer worked; message `a`, also carries `CONTEXT.md`, this document and regenerated plugin registrants).
- [x] T2 done — commit `8a0e80d` (same origin; message `aa`).

Verification (parent re-run on `8a0e80d`): `flutter analyze` → no issues; `flutter test` → 25 passed. Writer RED/GREEN for T1: 0/18 against stubs, then 18/18.

Known gaps:
- `dart run build_runner build` fails on this host with build_runner 2.15 + sqlite3 3.x; `dart run build_runner build --force-jit` works.
- `sync_batch` is granted to `authenticated` only; without login, uploads fail and stay retryable.
- Authored size ~1,430 lines (forecast ~700); chain strategy not chosen, no PR requested yet.
- Review: assessed `medium`, `review_due` (`slice_budget_reached`) against base `10023a8`; candidate consent declined by the user for this change (no review record; future reviews stay enabled).

Accepted deviations: `SyncService` interface in its own file; Drift getter `targetTable` (SQL `table_name`); `requeueInterrupted()` recovers rows stuck in `syncing`; ids missing from the RPC response become `error`; one batch of 50 per `syncPending()` call.

Next step: add login so real sync can run.
