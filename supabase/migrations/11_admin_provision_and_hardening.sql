-- T1: admin provisioning RPC, staff uploads to the assistance bucket, execute-grant hardening.

-- 1) admin_provision_user: called ONLY by the admin-create-user Edge Function (service_role).
create or replace function public.admin_provision_user(
  p_user_id uuid,
  p_email text,
  p_full_name text,
  p_role public.user_role,
  p_phone text default null,
  p_zone_ids uuid[] default '{}',
  p_community_id uuid default null,
  p_age_range text default null
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

  insert into public.profiles (id, full_name, phone, email, role, status)
  values (p_user_id, trim(p_full_name), nullif(trim(coalesce(p_phone, '')), ''), lower(trim(p_email)), p_role, 'active');

  if p_role = 'farmer' then
    insert into public.farmers (user_id, community_id, age_range, phone, active)
    values (p_user_id, p_community_id, p_age_range, nullif(trim(coalesce(p_phone, '')), ''), true)
    returning id into v_farmer_id;
  elsif p_role in ('technician', 'supervisor') and coalesce(array_length(p_zone_ids, 1), 0) > 0 then
    insert into public.user_zones (user_id, zone_id)
    select p_user_id, z from unnest(p_zone_ids) as z;
  end if;

  return jsonb_build_object('user_id', p_user_id, 'farmer_id', v_farmer_id, 'role', p_role);
end;
$$;

revoke all on function public.admin_provision_user(uuid, text, text, public.user_role, text, uuid[], uuid, text) from public, anon, authenticated;
grant execute on function public.admin_provision_user(uuid, text, text, public.user_role, text, uuid[], uuid, text) to service_role;

-- 2) Staff (technician/supervisor) may upload assistance evidence for farmers they can access.
create policy assistance_staff_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'assistance'
    and public.app_role() in ('technician', 'supervisor')
    and public.can_access_farmer(((storage.foldername(name))[1])::uuid)
  );

-- Technicians also attach external sheets on behalf of a farmer.
create policy "external-documents_staff_insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'external-documents'
    and public.app_role() in ('technician', 'supervisor')
    and public.can_access_farmer(((storage.foldername(name))[1])::uuid)
  );

-- 3) Hardening: trigger-only functions need no EXECUTE grant; policy helpers stay for authenticated only.
do $$
declare f text;
begin
  foreach f in array array[
    'audit_row_change()', 'log_incident_status()', 'restrict_incident_update()',
    'set_incident_closed_at()', 'set_harvest_estimated_weight()', 'touch_farmer_activity()',
    'validate_activity_requirements()', 'complete_reminders_on_confirmation()',
    'rls_auto_enable()', 'mark_overdue_reminders()'
  ] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;

  foreach f in array array[
    'app_role()', 'app_setting_int(text, integer)', 'current_farmer_id()', 'has_zone_access(uuid)',
    'can_access_assistance(uuid)', 'can_access_cycle(uuid)', 'can_access_farmer(uuid)',
    'can_access_harvest(uuid)', 'can_access_incident(uuid)', 'can_access_parcel(uuid)',
    'can_view_profile(uuid)', 'sync_batch(text, jsonb)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated, service_role', f);
  end loop;
end $$;

alter function public.set_updated_at() set search_path = public;
