-- ============================================================================
-- AgroApp · PARTE 9.2 — VERIFICACIÓN
-- Queries de comprobación. Ejecutar tras aplicar las migraciones.
-- ============================================================================

-- 1) Tablas creadas y confirmación de RLS activo en todas
select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r'
order by c.relname;

-- Resumen: tablas SIN RLS (debe devolver 0 filas)
select c.relname as table_without_rls
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity = false;

-- 2) Conteo de filas sembradas en cada catálogo
select 'zones' as catalog, count(*) as rows from public.zones
union all select 'communities', count(*) from public.communities
union all select 'crops', count(*) from public.crops
union all select 'units', count(*) from public.units
union all select 'unit_equivalences', count(*) from public.unit_equivalences
union all select 'products', count(*) from public.products
union all select 'product_units', count(*) from public.product_units
union all select 'activity_types', count(*) from public.activity_types
union all select 'activity_type_units', count(*) from public.activity_type_units
union all select 'crop_harvest_units', count(*) from public.crop_harvest_units
union all select 'pruning_types', count(*) from public.pruning_types
union all select 'symptom_types', count(*) from public.symptom_types
union all select 'assistance_categories', count(*) from public.assistance_categories
union all select 'assistance_subtypes', count(*) from public.assistance_subtypes
union all select 'expense_categories', count(*) from public.expense_categories
union all select 'buyers', count(*) from public.buyers
union all select 'reference_prices', count(*) from public.reference_prices
union all select 'app_settings', count(*) from public.app_settings
order by catalog;

-- 3) PRUEBA DE IDEMPOTENCIA de sync_batch (mismo UUID dos veces → no duplica)
-- Requiere sesión autenticada de un agricultor con acceso a la parcela.
-- Ejemplo (descomentar y ajustar UUIDs):
--
-- select public.sync_batch('device-demo-1', jsonb_build_array(
--   jsonb_build_object(
--     'table','incidents',
--     'id','eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
--     'client_created_at', now(),
--     'payload', jsonb_build_object(
--        'parcel_id','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
--        'farmer_id','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
--        'crop_id',(select id from public.crops where code='maiz'),
--        'symptom_type_id',(select id from public.symptom_types where code='manchas'),
--        'description','prueba idempotencia'
--     )
--   )
-- ));
-- Repetir la MISMA llamada y luego verificar:
-- select count(*) from public.incidents where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';  -- esperado: 1

-- 4) PRUEBA DE AISLAMIENTO: un farmer no puede leer parcelas de otro
-- Simula el JWT del agricultor demo (ver 10_seed_demo.sql):
--
-- select set_config('request.jwt.claims',
--   json_build_object('sub','11111111-1111-1111-1111-111111111111','role','authenticated')::text, true);
-- set local role authenticated;
-- select count(*) as parcelas_visibles from public.parcels;               -- solo las de Don Manuel
-- select count(*) as parcelas_ajenas from public.parcels
--   where farmer_id <> public.current_farmer_id();                        -- esperado: 0
-- reset role;

-- 5) Vista de adopción (usa app_settings)
-- select adoption_status, count(*) from public.v_adoption_status group by adoption_status;
