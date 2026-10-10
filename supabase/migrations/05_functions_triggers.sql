-- ============================================================================
-- AgroApp · PARTE 4 — FUNCIONES Y TRIGGERS
-- Funciones auxiliares SECURITY DEFINER + SET search_path = public.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) set_updated_at
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'zones','communities','crops','units','unit_equivalences','products','activity_types',
    'pruning_types','symptom_types','assistance_categories','assistance_subtypes',
    'expense_categories','buyers','reference_prices','app_settings','profiles','farmers',
    'parcels','crop_cycles','activities','expenses','incidents','incident_photos',
    'technical_assistance','assistance_documents','recommendations',
    'recommendation_confirmations','reminders','harvests','surplus_sales',
    'residue_management','notifications','device_tokens'
  ]
  loop
    execute format('drop trigger if exists %I on public.%I', 'trg_'||t||'_updated_at', t);
    execute format('create trigger %I before update on public.%I for each row execute function public.set_updated_at()', 'trg_'||t||'_updated_at', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2) Helpers de acceso / rol
create or replace function public.app_role()
returns public.user_role
language sql stable security definer set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.current_farmer_id()
returns uuid
language sql stable security definer set search_path = public
as $$
  select id from public.farmers where user_id = auth.uid() and active = true limit 1;
$$;

create or replace function public.has_zone_access(p_zone_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select case
    when public.app_role() = 'admin' then true
    when public.app_role() = 'supervisor' then
      (not exists (select 1 from public.user_zones uz where uz.user_id = auth.uid()))
      or exists (select 1 from public.user_zones uz where uz.user_id = auth.uid() and uz.zone_id = p_zone_id)
    else
      exists (select 1 from public.user_zones uz where uz.user_id = auth.uid() and uz.zone_id = p_zone_id)
  end;
$$;

create or replace function public.can_access_parcel(p_parcel_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select case
    when p_parcel_id is null then false
    when public.app_role() = 'admin' then true
    when public.app_role() = 'farmer' then
      exists (select 1 from public.parcels p where p.id = p_parcel_id and p.farmer_id = public.current_farmer_id())
    when public.app_role() = 'technician' then
      exists (select 1 from public.parcels p where p.id = p_parcel_id and public.has_zone_access(p.zone_id))
      or exists (select 1 from public.technician_parcels tp where tp.parcel_id = p_parcel_id and tp.technician_id = auth.uid())
    when public.app_role() = 'supervisor' then
      exists (select 1 from public.parcels p where p.id = p_parcel_id and public.has_zone_access(p.zone_id))
    else false
  end;
$$;

create or replace function public.can_access_farmer(p_farmer_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select case
    when p_farmer_id is null then false
    when public.app_role() = 'admin' then true
    when public.app_role() = 'farmer' then p_farmer_id = public.current_farmer_id()
    else exists (select 1 from public.parcels p where p.farmer_id = p_farmer_id and public.can_access_parcel(p.id))
  end;
$$;

create or replace function public.can_access_cycle(p_cycle_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.can_access_parcel(parcel_id) from public.crop_cycles where id = p_cycle_id;
$$;

create or replace function public.can_access_harvest(p_harvest_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.can_access_parcel(parcel_id) from public.harvests where id = p_harvest_id;
$$;

create or replace function public.can_access_incident(p_incident_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.can_access_parcel(parcel_id) from public.incidents where id = p_incident_id;
$$;

create or replace function public.can_access_assistance(p_assistance_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.can_access_parcel(parcel_id) from public.technical_assistance where id = p_assistance_id;
$$;

create or replace function public.can_view_profile(p_profile_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select case
    when p_profile_id is null then false
    when p_profile_id = auth.uid() then true
    when public.app_role() = 'admin' then true
    else exists (select 1 from public.farmers f where f.user_id = p_profile_id and public.can_access_farmer(f.id))
  end;
$$;

create or replace function public.app_setting_int(p_key text, p_default integer)
returns integer
language sql stable security definer set search_path = public
as $$
  select coalesce((select (value)::text::integer from public.app_settings where key = p_key), p_default);
$$;

-- ---------------------------------------------------------------------------
-- 3) Historial de incidencias
-- closed_at se ajusta en BEFORE (no toca tablas hijas); el historial se inserta
-- en AFTER para que la fila padre ya exista (evita violación de FK).
create or replace function public.set_incident_closed_at()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.status = 'closed' then
    new.closed_at := coalesce(new.closed_at, now());
  elsif tg_op = 'UPDATE' and old.status = 'closed' then
    new.closed_at := null;
  end if;
  return new;
end $$;

drop trigger if exists trg_incidents_closed_at on public.incidents;
create trigger trg_incidents_closed_at
  before insert or update on public.incidents
  for each row execute function public.set_incident_closed_at();

create or replace function public.log_incident_status()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.incident_status_history (incident_id, old_status, new_status, changed_by, comment)
    values (new.id, null, new.status, auth.uid(), 'created');
  elsif tg_op = 'UPDATE' and new.status is distinct from old.status then
    insert into public.incident_status_history (incident_id, old_status, new_status, changed_by)
    values (new.id, old.status, new.status, auth.uid());
  end if;
  return null;
end $$;

drop trigger if exists trg_incidents_status_history on public.incidents;
create trigger trg_incidents_status_history
  after insert or update on public.incidents
  for each row execute function public.log_incident_status();

-- ---------------------------------------------------------------------------
-- 3b) Restricción de columnas para técnicos en incidents
create or replace function public.restrict_incident_update()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if public.app_role() = 'technician' then
    if new.parcel_id is distinct from old.parcel_id
       or new.farmer_id is distinct from old.farmer_id
       or new.crop_id is distinct from old.crop_id
       or new.crop_cycle_id is distinct from old.crop_cycle_id
       or new.symptom_type_id is distinct from old.symptom_type_id
       or new.description is distinct from old.description
       or new.reported_at is distinct from old.reported_at then
      raise exception 'El técnico solo puede actualizar status, priority y assigned_technician_id';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_incidents_restrict_tech on public.incidents;
create trigger trg_incidents_restrict_tech
  before update on public.incidents
  for each row execute function public.restrict_incident_update();

-- ---------------------------------------------------------------------------
-- 4) touch_farmer_activity
create or replace function public.touch_farmer_activity()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare v_farmer uuid;
begin
  case tg_table_name
    when 'activities' then
      select p.farmer_id into v_farmer from public.crop_cycles cc join public.parcels p on p.id = cc.parcel_id where cc.id = new.crop_cycle_id;
    when 'incidents' then
      v_farmer := new.farmer_id;
    when 'expenses' then
      select p.farmer_id into v_farmer from public.parcels p where p.id = new.parcel_id;
    when 'harvests' then
      select p.farmer_id into v_farmer from public.parcels p where p.id = new.parcel_id;
    when 'surplus_sales' then
      select p.farmer_id into v_farmer from public.harvests h join public.parcels p on p.id = h.parcel_id where h.id = new.harvest_id;
    when 'residue_management' then
      select p.farmer_id into v_farmer from public.harvests h join public.parcels p on p.id = h.parcel_id where h.id = new.harvest_id;
    when 'recommendation_confirmations' then
      v_farmer := new.farmer_id;
  end case;
  if v_farmer is not null then
    update public.farmers set last_activity_at = now() where id = v_farmer;
  end if;
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['activities','incidents','expenses','harvests','surplus_sales','residue_management','recommendation_confirmations']
  loop
    execute format('drop trigger if exists %I on public.%I', 'trg_'||t||'_touch_farmer', t);
    execute format('create trigger %I after insert on public.%I for each row execute function public.touch_farmer_activity()', 'trg_'||t||'_touch_farmer', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 5) Confirmar recomendación → completar recordatorios ligados
create or replace function public.complete_reminders_on_confirmation()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  update public.reminders
     set status = 'completed'
   where recommendation_id = new.recommendation_id
     and status <> 'completed';
  return new;
end $$;

drop trigger if exists trg_reco_confirm_complete_reminders on public.recommendation_confirmations;
create trigger trg_reco_confirm_complete_reminders
  after insert on public.recommendation_confirmations
  for each row execute function public.complete_reminders_on_confirmation();

-- ---------------------------------------------------------------------------
-- 6) mark_overdue_reminders (+ intento de pg_cron)
create or replace function public.mark_overdue_reminders()
returns integer
language plpgsql security definer set search_path = public
as $$
declare n integer;
begin
  update public.reminders
     set status = 'overdue'
   where status = 'pending' and due_date < current_date;
  get diagnostics n = row_count;
  return n;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      perform cron.unschedule('mark_overdue_reminders');
    exception when others then null;
    end;
    perform cron.schedule('mark_overdue_reminders', '0 6 * * *', 'select public.mark_overdue_reminders();');
  end if;
exception when others then null;
end $$;

-- ---------------------------------------------------------------------------
-- 7) Peso estimado de cosecha (solo con equivalencia validada)
create or replace function public.set_harvest_estimated_weight()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare v_crop uuid; v_kg numeric;
begin
  if new.total_unit_id is null or new.total_quantity is null then
    new.estimated_weight_kg := null;
    return new;
  end if;
  select cc.crop_id into v_crop from public.crop_cycles cc where cc.id = new.crop_cycle_id;
  select ue.kg_per_unit into v_kg
    from public.unit_equivalences ue
   where ue.validated = true
     and ue.unit_id = new.total_unit_id
     and (ue.crop_id = v_crop or ue.crop_id is null)
   order by ue.crop_id nulls last
   limit 1;
  if v_kg is not null then
    new.estimated_weight_kg := new.total_quantity * v_kg;
  else
    new.estimated_weight_kg := null;
  end if;
  return new;
end $$;

drop trigger if exists trg_harvests_estimated_weight on public.harvests;
create trigger trg_harvests_estimated_weight
  before insert or update on public.harvests
  for each row execute function public.set_harvest_estimated_weight();

-- ---------------------------------------------------------------------------
-- 8) Auditoría genérica
create or replace function public.audit_row_change()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.audit_logs (actor_id, action, table_name, record_id, old_data, new_data)
    values (auth.uid(), 'INSERT', tg_table_name, new.id, null, to_jsonb(new));
  elsif tg_op = 'UPDATE' then
    insert into public.audit_logs (actor_id, action, table_name, record_id, old_data, new_data)
    values (auth.uid(), 'UPDATE', tg_table_name, new.id, to_jsonb(old), to_jsonb(new));
  elsif tg_op = 'DELETE' then
    insert into public.audit_logs (actor_id, action, table_name, record_id, old_data, new_data)
    values (auth.uid(), 'DELETE', tg_table_name, old.id, to_jsonb(old), null);
  end if;
  return coalesce(new, old);
end $$;

do $$
declare t text;
begin
  foreach t in array array['technical_assistance','recommendations','incidents','profiles','parcels','harvests']
  loop
    execute format('drop trigger if exists %I on public.%I', 'trg_'||t||'_audit', t);
    execute format('create trigger %I after insert or update or delete on public.%I for each row execute function public.audit_row_change()', 'trg_'||t||'_audit', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 9) Validación de requisitos de actividad
create or replace function public.validate_activity_requirements()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare v_req_product boolean; v_req_pruning boolean;
begin
  select requires_product, requires_pruning_type into v_req_product, v_req_pruning
    from public.activity_types where id = new.activity_type_id;
  if coalesce(v_req_pruning, false) and new.pruning_type_id is null then
    raise exception 'El tipo de actividad requiere pruning_type_id';
  end if;
  if coalesce(v_req_product, false) and new.product_id is null then
    raise exception 'El tipo de actividad requiere product_id';
  end if;
  return new;
end $$;

drop trigger if exists trg_activities_validate on public.activities;
create trigger trg_activities_validate
  before insert or update on public.activities
  for each row execute function public.validate_activity_requirements();
