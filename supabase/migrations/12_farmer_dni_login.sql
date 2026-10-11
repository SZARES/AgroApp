-- Farmers sign in with DNI (8 digits) + password. Supabase Auth needs an email, so the
-- login email is derived: <dni>@agricultores.agroapp. Other roles keep real emails.

alter table public.farmers add column if not exists dni text;
alter table public.farmers drop constraint if exists farmers_dni_format;
alter table public.farmers add constraint farmers_dni_format check (dni is null or dni ~ '^[0-9]{8}$');
create unique index if not exists farmers_dni_unique on public.farmers (dni) where deleted_at is null;

-- Demo farmer ("Don Manuel") moves to DNI login.
update public.farmers set dni = '71226316' where user_id = '11111111-1111-1111-1111-111111111111' and dni is null;
update auth.users set email = '71226316@agricultores.agroapp'
  where id = '11111111-1111-1111-1111-111111111111' and email = 'donmanuel@demo.agroapp';
update public.profiles set email = '71226316@agricultores.agroapp'
  where id = '11111111-1111-1111-1111-111111111111' and email = 'donmanuel@demo.agroapp';

drop function if exists public.admin_provision_user(uuid, text, text, public.user_role, text, uuid[], uuid, text);

create or replace function public.admin_provision_user(
  p_user_id uuid,
  p_email text,
  p_full_name text,
  p_role public.user_role,
  p_phone text default null,
  p_zone_ids uuid[] default '{}',
  p_community_id uuid default null,
  p_age_range text default null,
  p_dni text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_farmer_id uuid;
begin
  if coalesce(trim(p_full_name), '') = '' then
    raise exception 'full_name es obligatorio';
  end if;
  if p_role = 'farmer' and coalesce(p_dni, '') !~ '^[0-9]{8}$' then
    raise exception 'El DNI del agricultor debe tener 8 números';
  end if;

  insert into public.profiles (id, full_name, phone, email, role, status)
  values (p_user_id, trim(p_full_name), nullif(trim(coalesce(p_phone, '')), ''), lower(trim(p_email)), p_role, 'active');

  if p_role = 'farmer' then
    insert into public.farmers (user_id, dni, community_id, age_range, phone, active)
    values (p_user_id, p_dni, p_community_id, p_age_range, nullif(trim(coalesce(p_phone, '')), ''), true)
    returning id into v_farmer_id;
  elsif p_role in ('technician', 'supervisor') and coalesce(array_length(p_zone_ids, 1), 0) > 0 then
    insert into public.user_zones (user_id, zone_id)
    select p_user_id, z from unnest(p_zone_ids) as z;
  end if;

  return jsonb_build_object('user_id', p_user_id, 'farmer_id', v_farmer_id, 'role', p_role);
end;
$$;

revoke all on function public.admin_provision_user(uuid, text, text, public.user_role, text, uuid[], uuid, text, text) from public, anon, authenticated;
grant execute on function public.admin_provision_user(uuid, text, text, public.user_role, text, uuid[], uuid, text, text) to service_role;
