-- ============================================================================
-- AgroApp · PARTE 8 — RPC DE SINCRONIZACIÓN
-- sync_batch: idempotente (ON CONFLICT (id) DO NOTHING). SECURITY INVOKER
-- para que apliquen las políticas RLS del usuario que sincroniza.
-- ============================================================================

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
    'residue_management','recommendation_confirmations','technical_assistance','assistance_documents'
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

grant execute on function public.sync_batch(text, jsonb) to authenticated;
