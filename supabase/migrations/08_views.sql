-- ============================================================================
-- AgroApp · PARTE 7 — VISTAS (security_invoker = true)
-- ============================================================================

-- 1) Tiempos de respuesta de incidencias
create or replace view public.v_incident_response_times with (security_invoker = true) as
select
  i.id as incident_id,
  i.parcel_id,
  i.status,
  i.reported_at,
  min(h.changed_at) filter (where h.new_status = 'under_review') as under_review_at,
  min(h.changed_at) filter (where h.new_status = 'attended') as attended_at,
  round(extract(epoch from (min(h.changed_at) filter (where h.new_status = 'under_review') - i.reported_at)) / 3600.0, 2) as hours_to_review,
  round(extract(epoch from (min(h.changed_at) filter (where h.new_status = 'attended') - i.reported_at)) / 3600.0, 2) as hours_to_attention
from public.incidents i
left join public.incident_status_history h on h.incident_id = i.id
group by i.id;

-- 2) KPI global agrupable por zona
create or replace view public.v_kpi_overview with (security_invoker = true) as
with z as (
  select id, name from public.zones where deleted_at is null
),
active_farmers as (
  select p.zone_id, count(distinct f.id) as n
  from public.farmers f
  join public.parcels p on p.farmer_id = f.id
  where f.active and f.deleted_at is null and p.deleted_at is null
  group by p.zone_id
),
inc_z as (
  select p.zone_id, i.status
  from public.incidents i
  join public.parcels p on p.id = i.parcel_id
  where i.deleted_at is null
),
open_alerts as (select zone_id, count(*) n from inc_z where status <> 'closed' group by zone_id),
closed_alerts as (select zone_id, count(*) n from inc_z where status = 'closed' group by zone_id),
attended as (select zone_id, count(*) n from inc_z where status in ('attended','closed') group by zone_id),
assist as (
  select p.zone_id, count(*) n
  from public.technical_assistance ta
  join public.parcels p on p.id = ta.parcel_id
  where ta.deleted_at is null
  group by p.zone_id
),
reco as (
  select p.zone_id,
    count(*) as issued,
    count(rc.id) as confirmed
  from public.recommendations r
  join public.parcels p on p.id = r.parcel_id
  left join public.recommendation_confirmations rc on rc.recommendation_id = r.id and rc.deleted_at is null
  where r.deleted_at is null
  group by p.zone_id
),
resp as (
  select p.zone_id, avg(v.hours_to_attention) as avg_hours
  from public.v_incident_response_times v
  join public.parcels p on p.id = v.parcel_id
  group by p.zone_id
)
select
  z.id as zone_id,
  z.name as zone_name,
  coalesce(af.n,0) as active_farmers,
  coalesce(oa.n,0) as open_alerts,
  coalesce(att.n,0) as attended_cases,
  coalesce(ca.n,0) as closed_cases,
  coalesce(a.n,0) as technical_assistance_count,
  round(rr.avg_hours, 2) as avg_attention_hours,
  case when coalesce(rc.issued,0) = 0 then null else round(rc.confirmed::numeric / rc.issued, 4) end as recommendation_completion_rate
from z
left join active_farmers af on af.zone_id = z.id
left join open_alerts oa on oa.zone_id = z.id
left join closed_alerts ca on ca.zone_id = z.id
left join attended att on att.zone_id = z.id
left join assist a on a.zone_id = z.id
left join reco rc on rc.zone_id = z.id
left join resp rr on rr.zone_id = z.id;

-- 3) Resumen por zona
create or replace view public.v_zone_summary with (security_invoker = true) as
select
  z.id as zone_id,
  z.name as zone_name,
  (select count(distinct p.farmer_id) from public.parcels p where p.zone_id = z.id and p.deleted_at is null) as producers,
  (select count(*) from public.incidents i join public.parcels p on p.id = i.parcel_id
     where p.zone_id = z.id and i.deleted_at is null and i.status <> 'closed') as open_alerts,
  (select count(*) from public.incidents i join public.parcels p on p.id = i.parcel_id
     where p.zone_id = z.id and i.deleted_at is null and i.status in ('attended','closed')) as attended_alerts
from public.zones z
where z.deleted_at is null;

-- 4) Carga de trabajo por técnico (distribución, no vigilancia)
create or replace view public.v_technician_workload with (security_invoker = true) as
select
  pr.id as technician_id,
  pr.full_name,
  count(distinct ta.id) as assistance_count,
  count(distinct i.id) filter (where i.status = 'closed') as closed_cases,
  count(distinct i.id) filter (where i.status <> 'closed') as pending_cases
from public.profiles pr
left join public.technical_assistance ta on ta.technician_id = pr.id and ta.deleted_at is null
left join public.incidents i on i.assigned_technician_id = pr.id and i.deleted_at is null
where pr.role = 'technician' and pr.deleted_at is null
group by pr.id, pr.full_name;

-- 5) Estado de adopción por agricultor
create or replace view public.v_adoption_status with (security_invoker = true) as
select
  f.id as farmer_id,
  f.user_id,
  p.full_name,
  f.last_activity_at,
  case
    when f.last_activity_at is null then 'inactive'::public.adoption_status
    when f.last_activity_at >= now() - make_interval(days => public.app_setting_int('adoption_active_days', 30)) then 'active'::public.adoption_status
    when f.last_activity_at >= now() - make_interval(days => public.app_setting_int('adoption_low_usage_days', 60)) then 'low_usage'::public.adoption_status
    when f.last_activity_at >= now() - make_interval(days => public.app_setting_int('adoption_needs_support_days', 90)) then 'needs_support'::public.adoption_status
    else 'inactive'::public.adoption_status
  end as adoption_status
from public.farmers f
join public.profiles p on p.id = f.user_id
where f.deleted_at is null and f.active;

-- 6) Balance productivo por ciclo (producción por unidad, sin convertir a kg)
create or replace view public.v_crop_cycle_balance with (security_invoker = true) as
with exp as (
  select crop_cycle_id, sum(cost) as total_expenses
  from public.expenses where deleted_at is null group by crop_cycle_id
),
prod as (
  select h.crop_cycle_id, h.total_unit_id as unit_id,
         sum(h.total_quantity) as total_quantity,
         sum(coalesce(h.household_quantity,0)) as household_quantity,
         sum(coalesce(h.surplus_quantity,0)) as surplus_quantity
  from public.harvests h where h.deleted_at is null
  group by h.crop_cycle_id, h.total_unit_id
),
sales as (
  select h.crop_cycle_id, sum(coalesce(s.total_value,0)) as sales_income
  from public.surplus_sales s
  join public.harvests h on h.id = s.harvest_id
  where s.deleted_at is null
  group by h.crop_cycle_id
),
hh_value as (
  select h.crop_cycle_id,
         sum(coalesce(h.household_quantity,0) * coalesce(rp.price,0)) as estimated_household_value
  from public.harvests h
  left join public.reference_prices rp
    on rp.crop_id = (select crop_id from public.crop_cycles cc2 where cc2.id = h.crop_cycle_id)
   and rp.unit_id = h.total_unit_id
   and rp.active and rp.deleted_at is null
   and (rp.valid_from is null or rp.valid_from <= h.harvest_date)
   and (rp.valid_to is null or rp.valid_to >= h.harvest_date)
  where h.deleted_at is null
  group by h.crop_cycle_id
)
select
  cc.id as crop_cycle_id,
  cc.parcel_id,
  cc.crop_id,
  cc.status,
  coalesce(e.total_expenses,0) as total_expenses,
  coalesce(
    (select jsonb_agg(jsonb_build_object(
        'unit_id', p.unit_id,
        'total_quantity', p.total_quantity,
        'household_quantity', p.household_quantity,
        'surplus_quantity', p.surplus_quantity))
       from prod p where p.crop_cycle_id = cc.id), '[]'::jsonb) as production_by_unit,
  coalesce(s.sales_income,0) as sales_income,
  coalesce(hv.estimated_household_value,0) as estimated_household_value,
  true as is_reference_value
from public.crop_cycles cc
left join exp e on e.crop_cycle_id = cc.id
left join sales s on s.crop_cycle_id = cc.id
left join hh_value hv on hv.crop_cycle_id = cc.id
where cc.deleted_at is null;

-- 7) Gastos por zona, cultivo, categoría y periodo
create or replace view public.v_expenses_by_category with (security_invoker = true) as
select
  p.zone_id,
  cc.crop_id,
  e.category_id,
  date_trunc('month', e.expense_date)::date as period_month,
  e.currency,
  sum(e.cost) as total_cost
from public.expenses e
join public.parcels p on p.id = e.parcel_id
join public.crop_cycles cc on cc.id = e.crop_cycle_id
where e.deleted_at is null
group by p.zone_id, cc.crop_id, e.category_id, period_month, e.currency;

-- 8) Línea de tiempo por parcela
create or replace view public.v_parcel_timeline with (security_invoker = true) as
select cc.parcel_id, cc.planting_date as event_date, 'sowing'::text as event_type,
       'Siembra: ' || c.name as title, cc.id as ref_id
from public.crop_cycles cc
join public.crops c on c.id = cc.crop_id
where cc.deleted_at is null
union all
select cc.parcel_id, a.activity_date, 'activity'::text,
       coalesce(aty.name, 'Actividad'), a.id
from public.activities a
join public.crop_cycles cc on cc.id = a.crop_cycle_id
left join public.activity_types aty on aty.id = a.activity_type_id
where a.deleted_at is null
union all
select i.parcel_id, i.reported_at::date, 'incident'::text,
       'Incidencia: ' || st.name, i.id
from public.incidents i
join public.symptom_types st on st.id = i.symptom_type_id
where i.deleted_at is null
union all
select ta.parcel_id, ta.assistance_date, 'assistance'::text,
       'Asistencia: ' || ac.name, ta.id
from public.technical_assistance ta
join public.assistance_categories ac on ac.id = ta.category_id
where ta.deleted_at is null
union all
select r.parcel_id, rc.confirmed_at::date, 'recommendation_confirmed'::text,
       'Recomendación confirmada', r.id
from public.recommendation_confirmations rc
join public.recommendations r on r.id = rc.recommendation_id
where rc.deleted_at is null
union all
select h.parcel_id, h.harvest_date, 'harvest'::text,
       'Cosecha', h.id
from public.harvests h
where h.deleted_at is null;

-- 9) Cumplimiento de recomendaciones (por técnico y zona)
create or replace view public.v_recommendation_completion with (security_invoker = true) as
select
  p.zone_id,
  r.created_by as technician_id,
  count(*) as issued,
  count(rc.id) as confirmed,
  case when count(*) = 0 then null else round(count(rc.id)::numeric / count(*), 4) end as completion_rate
from public.recommendations r
join public.parcels p on p.id = r.parcel_id
left join public.recommendation_confirmations rc on rc.recommendation_id = r.id and rc.deleted_at is null
where r.deleted_at is null
group by p.zone_id, r.created_by;
