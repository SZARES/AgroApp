-- ============================================================================
-- AgroApp · PARTE 3 — ÍNDICES
-- ============================================================================

create index if not exists idx_incidents_status_reported_at on public.incidents (status, reported_at);
create index if not exists idx_incidents_parcel_id on public.incidents (parcel_id);
create index if not exists idx_incidents_assigned_tech on public.incidents (assigned_technician_id);

create index if not exists idx_activities_cycle_date on public.activities (crop_cycle_id, activity_date);

create index if not exists idx_assistance_parcel_date on public.technical_assistance (parcel_id, assistance_date);
create index if not exists idx_assistance_technician on public.technical_assistance (technician_id);

create index if not exists idx_reminders_farmer_status_due on public.reminders (farmer_id, status, due_date);

create index if not exists idx_harvests_cycle on public.harvests (crop_cycle_id);

create index if not exists idx_parcels_farmer on public.parcels (farmer_id);
create index if not exists idx_parcels_zone on public.parcels (zone_id);

create index if not exists idx_farmers_last_activity on public.farmers (last_activity_at);

create index if not exists idx_audit_logs_table_record on public.audit_logs (table_name, record_id);

create index if not exists idx_sync_log_device on public.sync_log (device_id);

-- Índices parciales (soft delete) en tablas grandes
create index if not exists idx_activities_cycle_active on public.activities (crop_cycle_id) where deleted_at is null;
create index if not exists idx_expenses_cycle_active on public.expenses (crop_cycle_id) where deleted_at is null;
create index if not exists idx_incidents_parcel_active on public.incidents (parcel_id) where deleted_at is null;
create index if not exists idx_assistance_parcel_active on public.technical_assistance (parcel_id) where deleted_at is null;
create index if not exists idx_harvests_cycle_active on public.harvests (crop_cycle_id) where deleted_at is null;
