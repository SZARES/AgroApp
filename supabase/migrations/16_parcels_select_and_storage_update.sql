-- Upsert/ON CONFLICT needs a SELECT policy that can see the new row from its
-- own columns. can_access_parcel(id) re-reads parcels and misses the row being
-- inserted, so farmer parcel sync got 403 forever.
drop policy if exists parcels_select on public.parcels;
create policy parcels_select on public.parcels for select to authenticated
  using (
    public.app_role() = 'admin'
    or (public.app_role() = 'farmer' and farmer_id = public.current_farmer_id())
    or (
      public.app_role() = 'technician'
      and (
        public.has_zone_access(zone_id)
        or exists (
          select 1
          from public.technician_parcels tp
          where tp.parcel_id = parcels.id
            and tp.technician_id = auth.uid()
        )
      )
    )
    or (public.app_role() = 'supervisor' and public.has_zone_access(zone_id))
  );

-- Storage upload uses upsert:true, which needs UPDATE as well as INSERT.
do $$
declare
  b text;
begin
  foreach b in array array['incidents', 'assistance', 'external-documents'] loop
    execute format(
      'drop policy if exists %I on storage.objects',
      b || '_farmer_update'
    );
    execute format(
      $policy$
      create policy %I on storage.objects for update to authenticated
        using (
          bucket_id = %L
          and (storage.foldername(name))[1] = public.current_farmer_id()::text
        )
        with check (
          bucket_id = %L
          and (storage.foldername(name))[1] = public.current_farmer_id()::text
        )
      $policy$,
      b || '_farmer_update',
      b,
      b
    );
  end loop;
end $$;
