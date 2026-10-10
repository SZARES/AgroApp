-- ============================================================================
-- AgroApp · PARTE 6 — STORAGE
-- 3 buckets privados, 5 MB máx. Rutas: {farmer_id}/{record_id}/{filename}
-- ============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('incidents','incidents',false,5242880,array['image/jpeg','image/png','image/webp']),
  ('assistance','assistance',false,5242880,array['image/jpeg','image/png','image/webp']),
  ('external-documents','external-documents',false,5242880,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Políticas sobre storage.objects
do $$
declare b text;
begin
  foreach b in array array['incidents','assistance','external-documents'] loop
    execute format('drop policy if exists %I on storage.objects', b||'_farmer_select');
    execute format('create policy %I on storage.objects for select to authenticated using (bucket_id = %L and (storage.foldername(name))[1] = public.current_farmer_id()::text)', b||'_farmer_select', b);

    execute format('drop policy if exists %I on storage.objects', b||'_farmer_insert');
    execute format('create policy %I on storage.objects for insert to authenticated with check (bucket_id = %L and (storage.foldername(name))[1] = public.current_farmer_id()::text)', b||'_farmer_insert', b);

    execute format('drop policy if exists %I on storage.objects', b||'_staff_select');
    execute format('create policy %I on storage.objects for select to authenticated using (bucket_id = %L and public.can_access_farmer((storage.foldername(name))[1]::uuid))', b||'_staff_select', b);

    execute format('drop policy if exists %I on storage.objects', b||'_admin_all');
    execute format('create policy %I on storage.objects for all to authenticated using (bucket_id = %L and public.app_role() = ''admin'') with check (bucket_id = %L and public.app_role() = ''admin'')', b||'_admin_all', b, b);
  end loop;
end $$;
