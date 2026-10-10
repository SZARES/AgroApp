# admin-user-provisioning

## Objective

Let a signed-in `admin` create the other users (`farmer`, `technician`, `supervisor`, `admin`) together with their role-specific data, without adding a `superadmin` role.

## Problem and why

Users only exist through `supabase/migrations/10_seed_demo.sql`, which writes straight into `auth.users`. Creating an Auth user needs the service role, which must never reach a client, and RLS cannot grant it. `CONTEXT.md` 3.4 already gives `admin` global management of users, so a fifth role would only duplicate it and force a rewrite of the enum and every policy.

## Scope

- `supabase/migrations/12_admin_user_provisioning.sql`: `public.admin_provision_user(...)`, one transaction that inserts `profiles`, the role data (`farmers` row for a farmer, `user_zones` rows for technician/supervisor) and an `audit_logs` entry. Executable by `service_role` only.
- `supabase/functions/admin-create-user/index.ts`: Edge Function that authenticates the caller, requires an active `admin` profile, creates the Auth user with the admin API, calls the RPC and deletes the Auth user if the RPC fails.
- `CONTEXT.md`: document the flow under 3.4.

## Out of scope

Admin web screen (W-14, no web app in this repo yet), editing/suspending/deleting users, password reset, email invitations, parcel assignment (`technician_parcels`).

## Constraints

- Only `admin` may call it; authorization reads `public.profiles`, never `user_metadata`.
- The service/secret key lives only in the Edge Function environment.
- The RPC is `security invoker`, `search_path = ''`, with `execute` revoked from `public`, `anon` and `authenticated`.
- No orphans: a failed profile insert removes the Auth user just created.
- The password is never logged or returned.
- `farmers.age_range` stays a range, never an exact age.

## Tasks

- [x] **T1 — Provisioning RPC and Edge Function** (route: delegated; trigger: 2 non-trivial files)
  - Acceptance: an active admin creating each role gets the expected rows (`profiles`, plus `farmers` or `user_zones`) and one `audit_logs` row; a non-admin actor is rejected with no rows written; `anon`/`authenticated` cannot execute the RPC; a failed RPC leaves no Auth user.
  - Test-first exception: no local runner (no Deno, no Supabase CLI on this host). SQL is checked on the remote schema inside a rolled-back transaction; the function by structural readback until it is deployed.
  - Checks: transactional SQL check (parent), structural readback of the function, `npm view` for the pinned `@supabase/supabase-js` version.
- [ ] **T2 — Deploy and end-to-end check** (route: inline; needs explicit user authorization for the remote project)
  - Acceptance: migration applied, function deployed with `verify_jwt = true`, unauthenticated call returns 401, security advisors show nothing new, admin call creates a user.

## Delivery

Strategy: `ask-on-risk`. Forecast: ~300 authored lines. Branch: `feat/admin-user-provisioning`, branch point `3d66828`.

## Progress

- [x] T1 written, not deployed — commit `c811436`.
- Review: receipt-driven development is on. Assessment against base `3d66828` (untracked excluded) → `review_due`, `slice_budget_reached`. Preflight STATUS stopped at `collect / intended_untracked_selection_required` because of the untracked build artifact `android/.kotlin/sessions/*.salive`; the selection payload is not documented, so no review was started. Outcome: unavailable, pending.

Verification for T1:
- SQL, on the remote schema as `service_role`, inside one `do` block that ends in `raise exception` (nothing persisted; confirmed afterwards that neither the function nor the test users exist): 4 profiles created; farmer name trimmed; 1 `farmers` row with community and age range, 0 zone rows for the farmer; technician with `[z1, z1, z2, null]` got 2 `user_zones` rows and a null phone from `''`; supervisor with no zones got 0; admin got no extra rows; 4 `audit_logs` rows; non-admin actor → `42501` and no profile; duplicate phone → `23505`; `anon` and `authenticated` cannot execute, `service_role` can.
- Edge Function: structural readback only. RPC parameter names match the SQL; `@supabase/supabase-js` pinned to `2.117.3` (`npm view`). Not type-checked and never run: no Deno on this host.

Known gaps:
- `auth.getUser`, `auth.admin.createUser`/`deleteUser` and the `email_exists` error code are unverified against 2.117.3 until the function runs.
- `Access-Control-Allow-Origin` is `*` until the admin web origin exists.
- `profiles.email` has no unique constraint; uniqueness relies on Auth.
- A `23505` answer does not say which unique field collided.

Next step: T2, which needs the user's explicit go-ahead to change the remote project.
