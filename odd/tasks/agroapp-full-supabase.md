# AgroApp full Supabase app (Android + web)

Branch: `feat/full-supabase-app`

## Objective
Replace every mock with real data: offline-first Flutter app (farmer, technician) and
Flutter web AIDER console (technician, supervisor, admin), all backed by the existing
Supabase project through View -> ViewModel -> Repository -> Drift, with only the Sync Engine
talking to Supabase.

## Assumptions
- Web AIDER is Flutter web in the same codebase (same design, same contracts).
- Backend schema (41 public tables, RLS, `sync_batch` RPC) already exists and is the source of truth.
- Catalogs are downloaded by the Sync Engine into Drift; no hardcoded catalogs.
- Photos compressed to 1024-1600 px before upload to private Storage buckets.

## Gaps found (exploration)
- No Edge Function `admin-create-user`, no admin RPC `admin_provision_user`.
- Drift has only `outbox` and `app_settings` tables; all feature screens use `mock_data.dart`.
- No dashboard/report RPCs; no Storage buckets verified.

## Tasks
- [x] T1 Backend: Edge Function admin-create-user + RPC admin_provision_user, storage staff-insert policies, EXECUTE hardening (dashboard v_* views already exist; check security_invoker in T11)
- [ ] T2 Data core: Drift schema for catalogs and domain tables (local_id, server_id, sync_status, timestamps, deleted_at), pull + push sync, 5 s poll
- [ ] T3 Auth + roles routing (farmer, technician, supervisor, admin), responsive shell (mobile vs web)
- [ ] T4 Farmer home with real data, parcels + map, add land
- [ ] T5 Sequential activity flow + expenses (offline)
- [ ] T6 Incident flow with 0-3 photos, case status, history
- [ ] T7 Technician: alerts inbox + map, take case, schedule visit, assistance, recommendations, close
- [ ] T8 Farmer: assistances, attendance confirmation, recommendation confirmation, external visit
- [ ] T9 Calendar + Piura reminders
- [ ] T10 Harvest + destination + sales + residue
- [ ] T11 Supervisor dashboard + Excel export, admin catalogs/users
- [ ] T12 UI polish: floating back button, animations, web 3-panel module reused everywhere

## Route declaration
Parent orchestrates; one bounded writer per task; read-only explorer for backend mapping first.

## Evidence log
- T1: migration `supabase/migrations/11_admin_provision_and_hardening.sql` applied; Edge Function `admin-create-user` v1 ACTIVE (verify_jwt, admin check, rollback of Auth user on RPC failure); RLS smoke test as farmer OK (role, farmer id, 1 parcel, 1 incident). Advisors: only intentional RLS-helper warnings + leaked-password protection (dashboard setting, not API-togglable).
- Contract notes for later tasks: `sync_batch` is insert-only and idempotent, rejects provider AIDER; technician writes (incident status, assistance, recommendations) go via PostgREST; storage paths must be `<farmer_id>/...`; no profile auto-creation on signup; order parent-before-child in batches.
