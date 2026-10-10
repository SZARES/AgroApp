-- ============================================================================
-- AgroApp · PARTE 3 — USUARIOS Y NÚCLEO (tablas)
-- Orden respeta dependencias. Offline: activities, expenses, incidents,
-- incident_photos, technical_assistance, assistance_documents,
-- recommendation_confirmations, harvests, surplus_sales, residue_management.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text null unique,
  email text null,
  role public.user_role not null default 'farmer',
  status public.user_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.profiles is 'Perfiles de usuario del dominio (agricultor, técnico, supervisor, admin).';

-- FK diferida de unit_equivalences.validated_by (profiles se crea aquí)
do $$ begin
  alter table public.unit_equivalences
    add constraint unit_equivalences_validated_by_fkey
    foreign key (validated_by) references public.profiles(id) on delete set null;
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- user_zones (puente)
create table if not exists public.user_zones (
  user_id uuid not null references public.profiles(id) on delete cascade,
  zone_id uuid not null references public.zones(id) on delete cascade,
  primary key (user_id, zone_id)
);
comment on table public.user_zones is 'Zonas autorizadas para técnicos y supervisores.';

-- ---------------------------------------------------------------------------
-- farmers
create table if not exists public.farmers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  community_id uuid null references public.communities(id) on delete set null,
  age_range text null check (age_range in ('18-29','30-39','40-49','50-59','60-69','70+')),
  phone text null,
  digital_profile text null,
  last_activity_at timestamptz null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.farmers is 'Agricultores atendidos por el programa (nunca guardar edad exacta).';

-- ---------------------------------------------------------------------------
-- parcels
create table if not exists public.parcels (
  id uuid primary key default gen_random_uuid(),
  farmer_id uuid not null references public.farmers(id) on delete cascade,
  zone_id uuid not null references public.zones(id) on delete restrict,
  name text not null,
  area numeric null check (area >= 0),
  area_unit_id uuid null references public.units(id) on delete set null,
  latitude numeric null check (latitude is null or (latitude between -90 and 90)),
  longitude numeric null check (longitude is null or (longitude between -180 and 180)),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.parcels is 'Parcelas de un agricultor dentro de una zona.';

-- ---------------------------------------------------------------------------
-- technician_parcels (puente)
create table if not exists public.technician_parcels (
  technician_id uuid not null references public.profiles(id) on delete cascade,
  parcel_id uuid not null references public.parcels(id) on delete cascade,
  primary key (technician_id, parcel_id)
);
comment on table public.technician_parcels is 'Asignación específica opcional de técnico a parcela.';

-- ---------------------------------------------------------------------------
-- crop_cycles
create table if not exists public.crop_cycles (
  id uuid primary key default gen_random_uuid(),
  parcel_id uuid not null references public.parcels(id) on delete cascade,
  crop_id uuid not null references public.crops(id) on delete restrict,
  planting_date date not null,
  end_date date null,
  status text not null default 'active' check (status in ('active','harvested','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.crop_cycles is 'Campañas/ciclos de cultivo de una parcela en el tiempo.';

-- ---------------------------------------------------------------------------
-- activities (offline)
create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  crop_cycle_id uuid not null references public.crop_cycles(id) on delete cascade,
  activity_type_id uuid not null references public.activity_types(id) on delete restrict,
  activity_date date not null,
  quantity numeric null check (quantity >= 0),
  unit_id uuid null references public.units(id) on delete set null,
  custom_unit_label text null,
  product_id uuid null references public.products(id) on delete set null,
  pruning_type_id uuid null references public.pruning_types(id) on delete set null,
  cost numeric null check (cost >= 0),
  notes text null,
  created_by uuid not null references public.profiles(id) on delete restrict,
  device_id text null,
  created_offline boolean not null default false,
  client_created_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.activities is 'Actividades agrícolas registradas por el agricultor o técnico.';

-- ---------------------------------------------------------------------------
-- expenses (offline)
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  crop_cycle_id uuid not null references public.crop_cycles(id) on delete cascade,
  parcel_id uuid not null references public.parcels(id) on delete cascade,
  category_id uuid not null references public.expense_categories(id) on delete restrict,
  subtype text null,
  expense_date date not null,
  cost numeric not null check (cost >= 0),
  currency text not null default 'PEN',
  duration numeric null check (duration is null or duration >= 0),
  duration_unit_id uuid null references public.units(id) on delete set null,
  energy_type public.energy_type null,
  activity_id uuid null references public.activities(id) on delete set null,
  notes text null,
  created_by uuid not null references public.profiles(id) on delete restrict,
  device_id text null,
  created_offline boolean not null default false,
  client_created_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.expenses is 'Gastos de producción por ciclo/parcela/categoría.';

-- ---------------------------------------------------------------------------
-- incidents (offline)
create table if not exists public.incidents (
  id uuid primary key default gen_random_uuid(),
  parcel_id uuid not null references public.parcels(id) on delete cascade,
  farmer_id uuid not null references public.farmers(id) on delete cascade,
  crop_id uuid not null references public.crops(id) on delete restrict,
  crop_cycle_id uuid null references public.crop_cycles(id) on delete set null,
  symptom_type_id uuid not null references public.symptom_types(id) on delete restrict,
  description text null,
  reported_at timestamptz not null default now(),
  status public.incident_status not null default 'reported',
  priority public.priority_level not null default 'medium',
  assigned_technician_id uuid null references public.profiles(id) on delete set null,
  closed_at timestamptz null,
  device_id text null,
  created_offline boolean not null default false,
  client_created_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.incidents is 'Alertas/incidencias fitosanitarias reportadas en una parcela.';

-- ---------------------------------------------------------------------------
-- incident_photos (offline)
create table if not exists public.incident_photos (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.incidents(id) on delete cascade,
  storage_path text not null,
  width integer null check (width is null or width > 0),
  height integer null check (height is null or height > 0),
  size_bytes integer null check (size_bytes is null or size_bytes > 0),
  taken_at timestamptz null,
  device_id text null,
  created_offline boolean not null default false,
  client_created_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.incident_photos is 'Fotos comprimidas de incidencias (solo storage_path, sin binarios).';

-- ---------------------------------------------------------------------------
-- incident_status_history (historial: sin updated_at/deleted_at)
create table if not exists public.incident_status_history (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.incidents(id) on delete cascade,
  old_status public.incident_status null,
  new_status public.incident_status not null,
  changed_by uuid null references public.profiles(id) on delete set null,
  changed_at timestamptz not null default now(),
  comment text null
);
comment on table public.incident_status_history is 'Historial de cambios de estado de incidencias.';

-- ---------------------------------------------------------------------------
-- technical_assistance (offline)
create table if not exists public.technical_assistance (
  id uuid primary key default gen_random_uuid(),
  farmer_id uuid not null references public.farmers(id) on delete cascade,
  parcel_id uuid not null references public.parcels(id) on delete cascade,
  incident_id uuid null references public.incidents(id) on delete set null,
  provider public.assistance_provider not null default 'AIDER',
  institution_name text null,
  technician_id uuid null references public.profiles(id) on delete set null,
  category_id uuid not null references public.assistance_categories(id) on delete restrict,
  subtype_id uuid null references public.assistance_subtypes(id) on delete set null,
  assistance_date date not null,
  topic text null,
  observations text null,
  next_followup_date date null,
  status public.assistance_status not null default 'completed',
  created_by uuid not null references public.profiles(id) on delete restrict,
  device_id text null,
  created_offline boolean not null default false,
  client_created_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.technical_assistance is 'Asistencias técnicas (AIDER internas; SENASA/OTHER externas).';

-- ---------------------------------------------------------------------------
-- assistance_documents (offline)
create table if not exists public.assistance_documents (
  id uuid primary key default gen_random_uuid(),
  assistance_id uuid not null references public.technical_assistance(id) on delete cascade,
  storage_path text not null,
  kind public.document_kind not null,
  comment text null,
  device_id text null,
  created_offline boolean not null default false,
  client_created_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.assistance_documents is 'Documentos/fotos de fichas de asistencia (sin OCR en el MVP).';

-- ---------------------------------------------------------------------------
-- recommendations
create table if not exists public.recommendations (
  id uuid primary key default gen_random_uuid(),
  assistance_id uuid not null references public.technical_assistance(id) on delete cascade,
  farmer_id uuid not null references public.farmers(id) on delete cascade,
  parcel_id uuid not null references public.parcels(id) on delete cascade,
  description text not null,
  due_date date null,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.recommendations is 'Recomendaciones emitidas en una asistencia técnica.';

-- ---------------------------------------------------------------------------
-- recommendation_confirmations (offline)
create table if not exists public.recommendation_confirmations (
  id uuid primary key default gen_random_uuid(),
  recommendation_id uuid not null unique references public.recommendations(id) on delete cascade,
  farmer_id uuid not null references public.farmers(id) on delete cascade,
  confirmed_at timestamptz not null default now(),
  comment text null,
  device_id text null,
  created_offline boolean not null default false,
  client_created_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.recommendation_confirmations is 'Confirmación del agricultor de recomendaciones (dada ≠ aplicada).';

-- ---------------------------------------------------------------------------
-- reminders
create table if not exists public.reminders (
  id uuid primary key default gen_random_uuid(),
  farmer_id uuid not null references public.farmers(id) on delete cascade,
  parcel_id uuid not null references public.parcels(id) on delete cascade,
  assistance_id uuid null references public.technical_assistance(id) on delete set null,
  recommendation_id uuid null references public.recommendations(id) on delete set null,
  title text not null,
  description text null,
  due_date date not null,
  status public.reminder_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.reminders is 'Recordatorios para el agricultor ligados a asistencia/recomendación.';

-- ---------------------------------------------------------------------------
-- harvests (offline)
create table if not exists public.harvests (
  id uuid primary key default gen_random_uuid(),
  crop_cycle_id uuid not null references public.crop_cycles(id) on delete cascade,
  parcel_id uuid not null references public.parcels(id) on delete cascade,
  harvest_date date not null,
  total_quantity numeric not null check (total_quantity >= 0),
  total_unit_id uuid not null references public.units(id) on delete restrict,
  custom_unit_label text null,
  household_quantity numeric null check (household_quantity is null or household_quantity >= 0),
  surplus_quantity numeric null check (surplus_quantity is null or surplus_quantity >= 0),
  estimated_weight_kg numeric null check (estimated_weight_kg is null or estimated_weight_kg >= 0),
  device_id text null,
  created_offline boolean not null default false,
  client_created_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null,
  constraint harvests_quantities_chk
    check (coalesce(household_quantity,0) + coalesce(surplus_quantity,0) <= total_quantity)
);
comment on table public.harvests is 'Cosechas por ciclo (autoconsumo + excedente con su unidad original).';

-- ---------------------------------------------------------------------------
-- surplus_sales (offline)
create table if not exists public.surplus_sales (
  id uuid primary key default gen_random_uuid(),
  harvest_id uuid not null references public.harvests(id) on delete cascade,
  quantity numeric not null check (quantity >= 0),
  unit_id uuid not null references public.units(id) on delete restrict,
  price numeric null check (price is null or price >= 0),
  price_unit_id uuid not null references public.units(id) on delete restrict,
  total_value numeric null check (total_value is null or total_value >= 0),
  buyer_id uuid null references public.buyers(id) on delete set null,
  sale_date date not null,
  device_id text null,
  created_offline boolean not null default false,
  client_created_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.surplus_sales is 'Ventas de excedente de cosecha.';

-- ---------------------------------------------------------------------------
-- residue_management (offline)
create table if not exists public.residue_management (
  id uuid primary key default gen_random_uuid(),
  harvest_id uuid not null references public.harvests(id) on delete cascade,
  residue_type text not null,
  quantity numeric null check (quantity is null or quantity >= 0),
  unit_id uuid null references public.units(id) on delete set null,
  custom_unit_label text null,
  destination public.residue_destination not null,
  notes text null,
  device_id text null,
  created_offline boolean not null default false,
  client_created_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.residue_management is 'Manejo de rastrojo/residuos de cosecha (cantidad opcional).';

-- ---------------------------------------------------------------------------
-- notifications
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  ref_table text null,
  ref_id uuid null,
  read_at timestamptz null,
  sent_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.notifications is 'Notificaciones in-app/push para usuarios.';

-- ---------------------------------------------------------------------------
-- device_tokens
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform text not null,
  last_seen_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.device_tokens is 'Tokens de dispositivo para FCM (base futura).';

-- ---------------------------------------------------------------------------
-- audit_logs (sin updated_at/deleted_at)
create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid null references public.profiles(id) on delete set null,
  action text not null,
  table_name text not null,
  record_id uuid not null,
  old_data jsonb null,
  new_data jsonb null,
  created_at timestamptz not null default now()
);
comment on table public.audit_logs is 'Bitácora de auditoría de cambios en tablas críticas.';

-- ---------------------------------------------------------------------------
-- sync_log (sin updated_at/deleted_at)
create table if not exists public.sync_log (
  id uuid primary key default gen_random_uuid(),
  device_id text not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  received_at timestamptz not null default now(),
  records_count integer not null default 0,
  synced_count integer not null default 0,
  failed_count integer not null default 0,
  errors jsonb null
);
comment on table public.sync_log is 'Registro de cada lote de sincronización recibido.';
