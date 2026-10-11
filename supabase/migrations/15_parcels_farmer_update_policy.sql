-- PostgREST upsert needs INSERT + UPDATE policies. Farmers could insert
-- parcels but not update, so "Agregar terreno" stayed stuck in the outbox.

drop policy if exists parcels_update on public.parcels;
create policy parcels_update on public.parcels for update to authenticated
  using (
    public.app_role() = 'admin'
    or (public.app_role() = 'farmer' and farmer_id = public.current_farmer_id())
    or (public.app_role() in ('technician', 'supervisor') and public.has_zone_access(zone_id))
  )
  with check (
    public.app_role() = 'admin'
    or (public.app_role() = 'farmer' and farmer_id = public.current_farmer_id())
    or (public.app_role() in ('technician', 'supervisor') and public.has_zone_access(zone_id))
  );

grant update on public.parcels to authenticated;
