-- ============================================================================
-- AgroApp · PARTE 12 — ALTA DE USUARIOS POR EL ADMINISTRADOR
-- RPC transaccional que completa el alta de un usuario ya creado en Auth:
-- perfil, datos propios del rol y registro de auditoría.
-- La invoca únicamente la Edge Function `admin-create-user` con la clave de
-- servicio. No existe rol `superadmin`: solo `admin` crea usuarios.
-- Idempotente: se puede volver a ejecutar sin efectos secundarios.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) admin_provision_user
--    SECURITY INVOKER + search_path vacío: todos los objetos van calificados.
--    Las violaciones de restricciones (23505, 23503, 23514) se propagan para
--    que quien llama las traduzca y revierta el usuario de Auth.
create or replace function public.admin_provision_user(
  p_actor_id     uuid,
  p_user_id      uuid,
  p_full_name    text,
  p_email        text,
  p_phone        text,
  p_role         public.user_role,
  p_zone_ids     uuid[] default '{}',
  p_community_id uuid   default null,
  p_age_range    text   default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_full_name text   := btrim(p_full_name);
  v_email     text   := nullif(btrim(p_email), '');
  v_phone     text   := nullif(btrim(p_phone), '');
  v_zone_ids  uuid[] := '{}';
begin
  -- El actor debe ser un administrador activo y no eliminado.
  if not exists (
    select 1
    from public.profiles p
    where p.id = p_actor_id
      and p.role = 'admin'
      and p.status = 'active'
      and p.deleted_at is null
  ) then
    raise exception 'only an active admin can create users'
      using errcode = '42501';
  end if;

  insert into public.profiles (id, full_name, phone, email, role)
  values (p_user_id, v_full_name, v_phone, v_email, p_role);

  if p_role = 'farmer' then
    -- Las zonas no aplican al agricultor: se ignoran.
    insert into public.farmers (user_id, community_id, age_range, phone)
    values (p_user_id, p_community_id, p_age_range, v_phone);

  elsif p_role in ('technician', 'supervisor') then
    -- Una fila por zona distinta; un arreglo vacío es válido.
    select coalesce(array_agg(distinct z.zone_id), '{}')
      into v_zone_ids
    from unnest(coalesce(p_zone_ids, '{}')) as z(zone_id)
    where z.zone_id is not null;

    insert into public.user_zones (user_id, zone_id)
    select p_user_id, z.zone_id
    from unnest(v_zone_ids) as z(zone_id);
  end if;
  -- `admin` no requiere filas adicionales.

  -- Auditoría: nunca se registra la contraseña.
  insert into public.audit_logs (actor_id, action, table_name, record_id, new_data)
  values (
    p_actor_id,
    'create_user',
    'profiles',
    p_user_id,
    jsonb_build_object(
      'full_name',    v_full_name,
      'email',        v_email,
      'phone',        v_phone,
      'role',         p_role,
      'zone_ids',     to_jsonb(v_zone_ids),
      'community_id', case when p_role = 'farmer' then p_community_id end
    )
  );

  return p_user_id;
end $$;

comment on function public.admin_provision_user(
  uuid, uuid, text, text, text, public.user_role, uuid[], uuid, text
) is
  'Completa el alta de un usuario creado en Auth: inserta profiles, los datos del rol (farmers o user_zones) y una fila en audit_logs. Exige que p_actor_id sea un admin activo. Solo ejecutable por service_role (Edge Function admin-create-user).';

-- ---------------------------------------------------------------------------
-- 2) Permisos de ejecución: solo service_role
revoke all on function public.admin_provision_user(
  uuid, uuid, text, text, text, public.user_role, uuid[], uuid, text
) from public, anon, authenticated;

grant execute on function public.admin_provision_user(
  uuid, uuid, text, text, text, public.user_role, uuid[], uuid, text
) to service_role;
