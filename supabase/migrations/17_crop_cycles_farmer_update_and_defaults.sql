-- Farmers need UPDATE so PostgREST upsert of crop_cycles can succeed, and
-- parcels created from the app often have no active cycle yet (activities /
-- harvests require one).

drop policy if exists crop_cycles_update on public.crop_cycles;
create policy crop_cycles_update on public.crop_cycles for update to authenticated
  using (
    public.app_role() = 'admin'
    or (
      public.app_role() in ('farmer', 'technician', 'supervisor')
      and public.can_access_parcel(parcel_id)
    )
  )
  with check (
    public.app_role() = 'admin'
    or (
      public.app_role() in ('farmer', 'technician', 'supervisor')
      and public.can_access_parcel(parcel_id)
    )
  );

grant update on public.crop_cycles to authenticated;

-- Default active cycle (Maíz when present) for parcels that still have none.
insert into public.crop_cycles (parcel_id, crop_id, planting_date, status)
select
  p.id,
  c.id,
  current_date,
  'active'
from public.parcels p
cross join lateral (
  select id
  from public.crops
  where deleted_at is null
    and active is distinct from false
  order by
    case
      when lower(coalesce(code, '')) = 'maiz' then 0
      when lower(name) like '%ma%z%' then 1
      else 2
    end,
    name
  limit 1
) c
where p.deleted_at is null
  and p.active is distinct from false
  and not exists (
    select 1
    from public.crop_cycles cc
    where cc.parcel_id = p.id
      and cc.status = 'active'
      and cc.deleted_at is null
  );
