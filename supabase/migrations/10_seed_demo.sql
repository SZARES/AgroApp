-- ============================================================================
-- AgroApp · PARTE 9.1 — SEEDS DE PRUEBA (OPCIONAL)
-- ⚠️ Solo ejecutar si se confirma. Requiere rol service role (crea auth.users).
-- Idempotente. No forma parte del esquema base.
-- ============================================================================

-- 1 agricultor (Don Manuel), 1 técnico, 1 supervisor y 1 admin de demo
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('11111111-1111-1111-1111-111111111111','00000000-0000-0000-0000-000000000000','authenticated','authenticated','donmanuel@demo.agroapp', crypt('demo1234', gen_salt('bf')), now(), now(), now(), '{"provider":"email","providers":["email"]}','{}'),
  ('22222222-2222-2222-2222-222222222222','00000000-0000-0000-0000-000000000000','authenticated','authenticated','tecnico@demo.agroapp', crypt('demo1234', gen_salt('bf')), now(), now(), now(), '{"provider":"email","providers":["email"]}','{}'),
  ('33333333-3333-3333-3333-333333333333','00000000-0000-0000-0000-000000000000','authenticated','authenticated','supervisor@demo.agroapp', crypt('demo1234', gen_salt('bf')), now(), now(), now(), '{"provider":"email","providers":["email"]}','{}'),
  ('44444444-4444-4444-4444-444444444444','00000000-0000-0000-0000-000000000000','authenticated','authenticated','admin@demo.agroapp', crypt('demo1234', gen_salt('bf')), now(), now(), now(), '{"provider":"email","providers":["email"]}','{}')
on conflict (id) do nothing;

-- Nota: reemplazar los password por hashes válidos si se necesita login real.
update auth.users set encrypted_password = crypt('demo1234', gen_salt('bf'))
 where id in (
   '11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222',
   '33333333-3333-3333-3333-333333333333','44444444-4444-4444-4444-444444444444'
 );

insert into public.profiles (id, full_name, phone, email, role) values
  ('11111111-1111-1111-1111-111111111111','Don Manuel','+51900000001','donmanuel@demo.agroapp','farmer'),
  ('22222222-2222-2222-2222-222222222222','Técnica Rosa','+51900000002','tecnico@demo.agroapp','technician'),
  ('33333333-3333-3333-3333-333333333333','Supervisor Luis','+51900000003','supervisor@demo.agroapp','supervisor'),
  ('44444444-4444-4444-4444-444444444444','Admin AgroApp','+51900000004','admin@demo.agroapp','admin')
on conflict (id) do nothing;

with z as (select id from public.zones where code = 'morropon'),
     c as (select id from public.communities where name = 'Comunidad Demo' limit 1)
insert into public.communities (zone_id, name)
select z.id, 'Comunidad Demo' from z
on conflict (zone_id, name) do nothing;

insert into public.user_zones (user_id, zone_id)
select '22222222-2222-2222-2222-222222222222', z.id from public.zones z where z.code = 'morropon'
on conflict do nothing;
insert into public.user_zones (user_id, zone_id)
select '33333333-3333-3333-3333-333333333333', z.id from public.zones z where z.code = 'morropon'
on conflict do nothing;

insert into public.farmers (id, user_id, community_id, age_range, phone)
select
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '11111111-1111-1111-1111-111111111111',
  c.id, '50-59', '+51900000001'
from public.communities c where c.name = 'Comunidad Demo'
on conflict (id) do nothing;

insert into public.parcels (id, farmer_id, zone_id, name, area, area_unit_id)
select
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  z.id, 'La Esperanza', 1.5, u.id
from public.zones z, public.units u
where z.code = 'morropon' and u.abbreviation = 'ha'
on conflict (id) do nothing;

insert into public.crop_cycles (id, parcel_id, crop_id, planting_date, status)
select
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  c.id, current_date - 90, 'active'
from public.crops c where c.code = 'maiz'
on conflict (id) do nothing;

insert into public.incidents (id, parcel_id, farmer_id, crop_id, crop_cycle_id, symptom_type_id, description, status, priority)
select
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  (select id from public.crops where code='maiz'),
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  s.id, 'Hojas con manchas amarillas en el lote demo', 'reported', 'medium'
from public.symptom_types s where s.code = 'manchas'
on conflict (id) do nothing;
