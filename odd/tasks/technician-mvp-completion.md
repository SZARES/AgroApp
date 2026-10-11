# technician-mvp-completion

## Objective
Give the `technician` role (web console + phone) everything the MVP plan lists for them (CONTEXT.md §3.2, §7, §13), with good UX and skeleton loaders.

## Problem
- Web: only the alert workspace works. `Parcelas` and `Calendario` are placeholders; there is no KPI dashboard (W-01), no alert filters (W-02), no farmer file (W-05), and assistance can only be registered inside an existing case (W-04).
- Phone: only `Casos` + `Mapa`. No KPIs, no farmers, no field assistance.
- Loading states are bare `CircularProgressIndicator`s.

## Scope
Technician surfaces + shared skeleton widget. Local-replica reads/writes only (offline-first). No new backend tables (technical_assistance.incident_id is nullable).

## Tasks
- [x] T1 Shared `Skeleton*` widgets and use in technician loading states
- [x] T2 Repository + models: farmers list/detail, KPIs, standalone assistance
- [x] T3 View models: farmers, farmer detail, dashboard
- [x] T4 UI web: dashboard (home), alert status filters, "Agricultores" module (ficha)
- [x] T5 UI phone: bottom navigation Inicio/Casos/Mapa/Agricultores, farmer detail + register assistance
- [x] T6 Tests + `flutter analyze` + `flutter test`

## Constraints
No commits/branches (user handles git). UI copy in Spanish (existing app), code/comments in English. Farmers' sensitive data stays local-replica only.

## Route
Delegated direct: one writer (2+ non-trivial files; reading prepares the write).
