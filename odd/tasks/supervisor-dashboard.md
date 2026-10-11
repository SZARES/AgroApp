# Supervisor Dashboard (T11)

## Objective
Fill the supervisor's empty **Inicio** in the AIDER web console with a KPI dashboard: adoption, % alertas resueltas, % recomendaciones confirmadas, tiempos de respuesta, producción/autoconsumo/excedente/gastos, and carga por técnico.

## Decision (Option B, user-approved 2026-10-11)
No DB changes. Aggregate on the client from the existing `security_invoker` views and base tables (supervisor RLS scopes them to accessible zones).

**Accepted limitation:** `carga por técnico` shows counts by masked technician id, **without names** — `profiles` RLS (`can_view_profile`) hides technician profiles from supervisors, so `v_technician_workload` returns zero rows for a supervisor. Names need Option A (a `security definer` function), deferred.

## Why
Supervisor currently sees `ModulePlaceholder` on Inicio. The KPI SQL already exists in `08_views.sql`; the web console is online-only, so reading Supabase views directly (AdminService pattern) is the right fit.

## Route / topology
Delegated-direct unavailable (broken subagent model config); implemented inline as a single writer thread. Multi-file feature.

## Data sources (all read-only, RLS-scoped)
- `v_kpi_overview` → zone_id, zone_name, active_farmers, open_alerts, attended_cases, closed_cases, technical_assistance_count, avg_attention_hours
- `v_zone_summary` → zone_id, producers (registered farmers, adoption denominator)
- `v_recommendation_completion` → zone_id, issued, confirmed
- `v_crop_cycle_balance` → parcel_id, production_by_unit (jsonb), total_expenses, sales_income, estimated_household_value
- `parcels` → id, zone_id (join map)
- `technical_assistance` → technician_id, parcel_id (load)
- `incidents` → assigned_technician_id, status, parcel_id (load)
- `units` → id, name, abbreviation (production labels)

## Aggregation (pure, unit-tested)
`SupervisorMetrics` computed globally and per zone. Derived: adoptionRate = active/registered; alertResolutionRate = closed/(open+closed); recommendationRate = confirmed/issued; avgResponseHours = attended-weighted mean of zone avg_attention_hours.

## Tasks
- [x] T1 Domain models `lib/domain/models/supervisor_dashboard.dart`
- [x] T2 `SupervisorService` + `SupabaseSupervisorService`
- [x] T3 `SupervisorRepository` + aggregation (global + per-zone)
- [x] T4 `SupervisorDashboardViewModel` (load/retry/zone filter)
- [x] T5 `SupervisorDashboardView` (3-panel: zone list + KPI dashboard)
- [x] T6 Wire DI (`dependencies.dart`) + render in `console_view.dart`
- [x] T7 Unit test for aggregation; `flutter analyze` clean

## Acceptance criteria
- Supervisor Inicio shows KPIs (not placeholder); territory/team/reports remain placeholders.
- Loads with loading/error/empty states; zone filter recomputes counts.
- Producción/autoconsumo/excedente shown **per unit** (no unit conversion, per CONTEXT).
- Expenses in S/ (PEN); no automatic currency/unit conversion.
- Carga por técnico shows counts by masked id with a visible note about names.
- `flutter analyze` clean; aggregation unit test passes.

## Next steps
- Apply for real against Supabase and verify RLS returns the supervisor's zones.
- Option A later: `security definer supervisor_dashboard()` for technician names + fewer queries.
- Repurpose territory/team/reports modules (separate features).
