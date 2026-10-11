-- T7: farmer confirms whether the technician showed up to a visit, and the
-- technician marks whether the farmer followed each recommendation.
-- recommendation_confirmations is farmer-authored and unique per recommendation,
-- so the technician's mark lives in its own table.

-- 1) visit_attendance_confirmations (farmer, offline via sync_batch)
create table if not exists public.visit_attendance_confirmations (
  id uuid primary key default gen_random_uuid(),
  assistance_id uuid not null references public.technical_assistance(id) on delete cascade,
  farmer_id uuid not null references public.farmers(id) on delete cascade,
  arrived boolean not null,
  comment text null,
  confirmed_at timestamptz not null default now(),
  device_id text null,
  created_offline boolean not null default false,
  client_created_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null,
  constraint visit_attendance_unique unique (assistance_id, farmer_id)
);
comment on table public.visit_attendance_confirmations is 'Confirmación del agricultor de si el técnico llegó a la visita.';
create index if not exists idx_visit_attendance_farmer on public.visit_attendance_confirmations (farmer_id);

-- 2) recommendation_followups (technician, direct upsert)
create table if not exists public.recommendation_followups (
  id uuid primary key default gen_random_uuid(),
  recommendation_id uuid not null unique references public.recommendations(id) on delete cascade,
  farmer_id uuid not null references public.farmers(id) on delete cascade,
  technician_id uuid not null references public.profiles(id) on delete restrict,
  followed boolean not null,
  comment text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.recommendation_followups is 'Marca del técnico: el agricultor siguió o no la recomendación.';
create index if not exists idx_reco_followups_farmer on public.recommendation_followups (farmer_id);

do $$
declare t text;
begin
  foreach t in array array['visit_attendance_confirmations', 'recommendation_followups']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop trigger if exists %I on public.%I', 'trg_' || t || '_updated_at', t);
    execute format('create trigger %I before update on public.%I for each row execute function public.set_updated_at()', 'trg_' || t || '_updated_at', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update on public.%I to authenticated', t);
  end loop;
end $$;

-- 3) RLS: visit attendance
drop policy if exists visit_attendance_select on public.visit_attendance_confirmations;
create policy visit_attendance_select on public.visit_attendance_confirmations for select to authenticated
  using (public.can_access_farmer(farmer_id));

drop policy if exists visit_attendance_insert on public.visit_attendance_confirmations;
create policy visit_attendance_insert on public.visit_attendance_confirmations for insert to authenticated
  with check (
    public.app_role() = 'farmer'
    and farmer_id = public.current_farmer_id()
    and public.can_access_assistance(assistance_id)
  );

drop policy if exists visit_attendance_admin_all on public.visit_attendance_confirmations;
create policy visit_attendance_admin_all on public.visit_attendance_confirmations for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- 4) RLS: recommendation follow-ups
drop policy if exists reco_followups_select on public.recommendation_followups;
create policy reco_followups_select on public.recommendation_followups for select to authenticated
  using (public.can_access_farmer(farmer_id));

drop policy if exists reco_followups_insert on public.recommendation_followups;
create policy reco_followups_insert on public.recommendation_followups for insert to authenticated
  with check (
    public.app_role() in ('technician', 'supervisor')
    and technician_id = auth.uid()
    and public.can_access_farmer(farmer_id)
  );

drop policy if exists reco_followups_update on public.recommendation_followups;
create policy reco_followups_update on public.recommendation_followups for update to authenticated
  using (public.app_role() in ('technician', 'supervisor') and public.can_access_farmer(farmer_id))
  with check (
    public.app_role() in ('technician', 'supervisor')
    and technician_id = auth.uid()
    and public.can_access_farmer(farmer_id)
  );

drop policy if exists reco_followups_admin_all on public.recommendation_followups;
create policy reco_followups_admin_all on public.recommendation_followups for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- 5) sync_batch: identical to 09 except the whitelist also accepts the attendance table.
create or replace function public.sync_batch(p_device_id text, p_records jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  r jsonb;
  v_table text;
  v_id uuid;
  v_payload jsonb;
  v_cols text;
  v_client timestamptz;
  v_synced jsonb := '[]'::jsonb;
  v_failed jsonb := '[]'::jsonb;
  v_records int := 0;
  v_synced_count int := 0;
  v_failed_count int := 0;
  v_whitelist text[] := array[
    'activities','expenses','incidents','incident_photos','harvests','surplus_sales',
    'residue_management','recommendation_confirmations','technical_assistance','assistance_documents',
    'visit_attendance_confirmations'
  ];
begin
  if p_records is null or jsonb_typeof(p_records) <> 'array' then
    raise exception 'p_records debe ser un arreglo JSON';
  end if;

  for r in select value from jsonb_array_elements(p_records) loop
    v_records := v_records + 1;
    v_id := null;
    begin
      v_table := r->>'table';
      if v_table is null or not (v_table = any(v_whitelist)) then
        raise exception 'Tabla no permitida: %', coalesce(v_table, '(null)');
      end if;

      v_id := (r->>'id')::uuid;
      if v_id is null then
        raise exception 'Cada registro requiere un id uuid';
      end if;

      v_payload := coalesce(r->'payload', '{}'::jsonb);
      v_payload := jsonb_set(v_payload, '{id}', to_jsonb(v_id), true);
      v_payload := jsonb_set(v_payload, '{device_id}', to_jsonb(p_device_id), true);
      v_payload := jsonb_set(v_payload, '{created_offline}', 'true'::jsonb, true);

      v_client := nullif(r->>'client_created_at', '')::timestamptz;
      if v_client is not null then
        v_payload := jsonb_set(v_payload, '{client_created_at}', to_jsonb(v_client), true);
      end if;

      if v_table = 'technical_assistance' and coalesce(v_payload->>'provider', 'AIDER') = 'AIDER' then
        raise exception 'sync_batch solo acepta asistencias externas (provider <> AIDER)';
      end if;

      select string_agg(quote_ident(k), ', ')
        into v_cols
        from jsonb_object_keys(v_payload) k
       where exists (
         select 1 from information_schema.columns c
          where c.table_schema = 'public' and c.table_name = v_table and c.column_name = k
       );

      if v_cols is null then
        raise exception 'Payload sin columnas válidas para %', v_table;
      end if;

      execute format(
        'insert into public.%1$I (%2$s) select %2$s from jsonb_populate_record(null::public.%1$I, $1) on conflict (id) do nothing',
        v_table, v_cols
      ) using v_payload;

      v_synced := v_synced || to_jsonb(v_id::text);
      v_synced_count := v_synced_count + 1;
    exception when others then
      v_failed := v_failed || jsonb_build_object('id', coalesce(v_id::text, r->>'id'), 'error', sqlerrm);
      v_failed_count := v_failed_count + 1;
    end;
  end loop;

  insert into public.sync_log (device_id, user_id, records_count, synced_count, failed_count, errors)
  values (p_device_id, auth.uid(), v_records, v_synced_count, v_failed_count, nullif(v_failed, '[]'::jsonb));

  return jsonb_build_object('synced', v_synced, 'failed', v_failed);
end $$;

revoke all on function public.sync_batch(text, jsonb) from public, anon;
grant execute on function public.sync_batch(text, jsonb) to authenticated, service_role;
