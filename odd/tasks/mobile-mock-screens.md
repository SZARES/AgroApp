# mobile-mock-screens

## Objective

Replace the placeholder Android screens with a navigable mock of the MVP critical flow — farmer reports → technician attends → farmer confirms → supervisor sees the result — and route each role to its mobile home after login.

## Problem and why

Only the farmer home exists with real navigation; the rest shows "Próximamente". The jury needs to see the cycle end to end. The technician currently lands on a static "Próximamente" list.

## Scope

- Remove the "AgroApp" AppBar title from the farmer home.
- Farmer home: four large actions — Registrar actividad, Reportar problema, Registrar cosecha, Mis asistencias.
- Farmer screens: Mi parcela, Registrar actividad, Detalle de actividad, Reportar problema, Foto del problema, Estado del caso, Registrar cosecha, Mis asistencias, Detalle de asistencia.
- Technician screens (mobile): Listado de incidencias, Detalle del caso, Registrar asistencia técnica, Programar seguimiento, Cambiar estado del caso.
- Login routing: `farmer` → farmer home, `technician` → technician incident list, `supervisor`/`admin` → existing placeholder (web-only roles).
- Static mock data in `lib/ui/mock/mock_data.dart`. Saving only shows a "Guardado en el celular" snackbar; nothing is written to Drift or Supabase.

## Out of scope

Supervisor dashboard, alerts center, indicators, admin catalogs (web roles). Real camera/photo capture (no new packages), real persistence, real sync wiring for the new screens, auth changes.

## Constraints

- Keep the existing `HomeViewModel` and sync indicator on the farmer home; do not change the data layer.
- Large tap targets and 20px+ text (`AppTheme`); one main question per screen; max 3 main actions per screen.
- UI copy in neutral Spanish; identifiers in English `snake_case` files.
- No `AppBar` title "AgroApp" on any farmer screen.

## Route

Inline. No delegation requested; the change is UI-only with static data, no shared writes.

## Tasks

- [x] **T1 — Mock data, shared widgets, role routing** (inline)
  - Acceptance: `mock_data.dart` exposes fields, activities, cases, assistances and technician incidents; `OptionTile` and `StatusBadge` widgets exist; a technician login lands on the incident list; farmer login lands on the new home without an AppBar title.
  - Checks: `flutter analyze`.
- [x] **T2 — Farmer screens** (inline)
  - Acceptance: the four home actions open their screens; parcela shows total area and each field with crop and status (bien / revisar / pendiente); activity, problem, photo, case status, harvest, assistances and assistance detail each render mock data and the primary button shows the save snackbar.
  - Checks: `flutter analyze`.
- [x] **T3 — Technician screens** (inline)
  - Acceptance: incident list → detail → register assistance / schedule follow-up / change status work end to end with mock data and return to the list.
  - Checks: `flutter analyze`.

## Verification

- Visual check on an Android emulator or device is the user's step; this run only proves compile and analysis.
- TDD exception: static mock UI with no runnable behaviour under test; a structural check (`flutter analyze`) is the proportionate check.

## Progress

- Branch `feat/mobile-mock-screens` created from `feat/admin-user-provisioning`.
- T1–T3 implemented. `flutter analyze lib`: no issues. `flutter build apk --debug`: built (first attempt failed with a transient Dart native-assets thread error, second attempt succeeded).
- Visual check on device: pending (user step).
- Next step: review the mock on an emulator and decide on the next phase (supervisor/admin web screens are out of scope here).
