-- ============================================================================
-- AgroApp · PARTE 2 — CATÁLOGOS (con seeds)
-- Todos con created_at/updated_at/deleted_at + active + sort_order, salvo los
-- que indican lo contrario. Tablas puente sin columnas estándar.
-- unit_equivalences.validated_by → profiles: la FK se agrega en 03_core.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- zones
create table if not exists public.zones (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.zones is 'Zonas geográficas del programa (Morropón, Sullana, Tumbes).';

insert into public.zones (code, name) values
  ('morropon','Morropón'),
  ('sullana','Sullana'),
  ('tumbes','Tumbes')
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- communities
create table if not exists public.communities (
  id uuid primary key default gen_random_uuid(),
  zone_id uuid not null references public.zones(id) on delete restrict,
  name text not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null,
  unique (zone_id, name)
);
comment on table public.communities is 'Comunidades/caseríos dentro de una zona.';

-- ---------------------------------------------------------------------------
-- crops
create table if not exists public.crops (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.crops is 'Catálogo de cultivos del programa.';

insert into public.crops (code, name) values
  ('maiz','Maíz'),
  ('banano','Banano'),
  ('limon','Limón')
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- units
create table if not exists public.units (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  abbreviation text not null unique,
  category public.unit_category not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.units is 'Catálogo de unidades de medida por categoría.';

insert into public.units (name, abbreviation, category) values
  ('miligramo','mg','weight'),
  ('gramo','g','weight'),
  ('kilogramo','kg','weight'),
  ('quintal','qq','weight'),
  ('tonelada','t','weight'),
  ('mililitro','mL','volume'),
  ('litro','L','volume'),
  ('galón','gal','volume'),
  ('saco','saco','container'),
  ('bolsa','bolsa','container'),
  ('jaba','jaba','container'),
  ('caja','caja','container'),
  ('balde','balde','container'),
  ('botella','botella','container'),
  ('bidón','bidon','container'),
  ('carretilla','carretilla','container'),
  ('unidad','und','productive'),
  ('racimo','racimo','productive'),
  ('mano','mano','productive'),
  ('atado','atado','productive'),
  ('metro cuadrado','m2','area'),
  ('hectárea','ha','area'),
  ('jornal','jornal','labor'),
  ('persona','persona','labor'),
  ('hora','hora','labor'),
  ('día','dia','labor'),
  ('hora de bombeo','h-bombeo','irrigation'),
  ('minutos','min','irrigation'),
  ('litros (riego)','L-riego','irrigation'),
  ('metro cúbico','m3','irrigation'),
  ('otro','otro','other')
on conflict (abbreviation) do nothing;

-- ---------------------------------------------------------------------------
-- unit_equivalences (no lleva active/sort_order: tabla de datos validados)
-- validated_by se deja SIN FK aquí; se agrega en 03_core tras crear profiles.
create table if not exists public.unit_equivalences (
  id uuid primary key default gen_random_uuid(),
  crop_id uuid null references public.crops(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete cascade,
  kg_per_unit numeric not null check (kg_per_unit > 0),
  validated boolean not null default false,
  validated_by uuid null,
  validated_at timestamptz null,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null,
  unique (crop_id, unit_id)
);
comment on table public.unit_equivalences is 'Equivalencias validadas a kg por cultivo/unidad (solo con validated=true se usa).';

-- ---------------------------------------------------------------------------
-- products
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null check (category in ('fertilizer','insecticide','fungicide','compost','seed','other')),
  form text not null check (form in ('solid','liquid','organic','other')),
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.products is 'Catálogo de productos/insumos usados en actividades y gastos.';

insert into public.products (name, category, form) values
  ('Compost','compost','organic'),
  ('Fertilizante sólido','fertilizer','solid'),
  ('Fertilizante foliar','fertilizer','liquid'),
  ('Otro','other','other')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- product_units (puente)
create table if not exists public.product_units (
  product_id uuid not null references public.products(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete cascade,
  primary key (product_id, unit_id)
);
comment on table public.product_units is 'Unidades permitidas por producto.';

insert into public.product_units (product_id, unit_id)
select p.id, u.id
from (values
  ('Fertilizante foliar','mL'),('Fertilizante foliar','L'),('Fertilizante foliar','botella'),('Fertilizante foliar','otro'),
  ('Compost','kg'),('Compost','saco'),('Compost','carretilla'),('Compost','otro'),
  ('Fertilizante sólido','kg'),('Fertilizante sólido','saco'),('Fertilizante sólido','otro')
) as m(product_name, abbr)
join public.products p on p.name = m.product_name
join public.units u on u.abbreviation = m.abbr
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- activity_types
create table if not exists public.activity_types (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  requires_product boolean not null default false,
  requires_pruning_type boolean not null default false,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.activity_types is 'Tipos de actividad agrícola configurables.';

insert into public.activity_types (code, name, requires_product, requires_pruning_type, sort_order) values
  ('irrigation','Riego', false, false, 10),
  ('fertilization','Abonamiento y fertilización', true, false, 20),
  ('pruning','Poda', false, true, 30),
  ('weeding','Limpieza y deshierbe', false, false, 40),
  ('phytosanitary','Aplicación fitosanitaria', true, false, 50),
  ('sowing','Siembra y resiembra', false, false, 60),
  ('other','Otra actividad', false, false, 99)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- activity_type_units (puente)
create table if not exists public.activity_type_units (
  activity_type_id uuid not null references public.activity_types(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete cascade,
  primary key (activity_type_id, unit_id)
);
comment on table public.activity_type_units is 'Unidades sugeridas por tipo de actividad.';

insert into public.activity_type_units (activity_type_id, unit_id)
select a.id, u.id
from (values
  ('irrigation','h-bombeo'),('irrigation','min'),('irrigation','L-riego'),('irrigation','m3'),
  ('sowing','kg'),('sowing','und'),('sowing','atado'),('sowing','otro'),
  ('fertilization','kg'),('fertilization','saco'),('fertilization','L'),('fertilization','otro')
) as m(code, abbr)
join public.activity_types a on a.code = m.code
join public.units u on u.abbreviation = m.abbr
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- crop_harvest_units (puente)
create table if not exists public.crop_harvest_units (
  crop_id uuid not null references public.crops(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete cascade,
  primary key (crop_id, unit_id)
);
comment on table public.crop_harvest_units is 'Unidades de cosecha válidas por cultivo.';

insert into public.crop_harvest_units (crop_id, unit_id)
select c.id, u.id
from (values
  ('maiz','kg'),('maiz','saco'),('maiz','jaba'),('maiz','otro'),
  ('banano','kg'),('banano','racimo'),('banano','jaba'),('banano','otro'),
  ('limon','kg'),('limon','saco'),('limon','jaba'),('limon','otro')
) as m(code, abbr)
join public.crops c on c.code = m.code
join public.units u on u.abbreviation = m.abbr
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- pruning_types
create table if not exists public.pruning_types (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.pruning_types is 'Catálogo de tipos de poda.';

insert into public.pruning_types (code, name, sort_order) values
  ('formacion','Formación', 10),
  ('crecimiento','Crecimiento', 20),
  ('produccion','Producción', 30),
  ('sanitaria','Sanitaria', 40),
  ('otra','Otra', 99)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- symptom_types
create table if not exists public.symptom_types (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.symptom_types is 'Catálogo de síntomas para incidencias.';

insert into public.symptom_types (code, name, sort_order) values
  ('hojas_amarillas','Hojas amarillas', 10),
  ('manchas','Manchas', 20),
  ('insectos','Insectos', 30),
  ('perforaciones','Perforaciones', 40),
  ('marchitez','Marchitez', 50),
  ('otro','Otro', 99)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- assistance_categories
create table if not exists public.assistance_categories (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.assistance_categories is 'Categorías de asistencia técnica.';

insert into public.assistance_categories (code, name, sort_order) values
  ('sanidad_vegetal','Sanidad vegetal', 10),
  ('manejo_productivo','Manejo productivo', 20),
  ('nutricion','Nutrición', 30),
  ('riego','Riego', 40),
  ('siembra','Siembra', 50),
  ('cosecha','Cosecha', 60)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- assistance_subtypes
create table if not exists public.assistance_subtypes (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.assistance_categories(id) on delete cascade,
  code text not null,
  name text not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null,
  unique (category_id, code)
);
comment on table public.assistance_subtypes is 'Subtipos de asistencia por categoría.';

insert into public.assistance_subtypes (category_id, code, name, sort_order)
select c.id, m.code, m.name, m.sort_order
from (values
  ('sanidad_vegetal','plaga','Plaga',10),
  ('sanidad_vegetal','enfermedad','Enfermedad',20),
  ('sanidad_vegetal','aplicacion_fitosanitaria','Aplicación fitosanitaria',30),
  ('manejo_productivo','poda_produccion','Poda de producción',10),
  ('manejo_productivo','poda_formacion','Poda de formación',20),
  ('manejo_productivo','poda_sanitaria','Poda sanitaria',30),
  ('manejo_productivo','limpieza','Limpieza',40),
  ('nutricion','compost','Compost',10),
  ('nutricion','abonamiento','Abonamiento',20),
  ('nutricion','fertilizacion_foliar','Fertilización foliar',30),
  ('nutricion','fertilizacion_suelo','Fertilización de suelo',40),
  ('riego','necesidad_riego','Necesidad de riego',10),
  ('riego','bomba','Bomba',20),
  ('riego','frecuencia','Frecuencia',30),
  ('riego','manejo_pozo','Manejo de pozo',40),
  ('siembra','instalacion','Instalación',10),
  ('siembra','densidad','Densidad',20),
  ('siembra','resiembra','Resiembra',30),
  ('cosecha','momento_cosecha','Momento de cosecha',10),
  ('cosecha','manejo','Manejo',20),
  ('cosecha','destino','Destino',30)
) as m(cat_code, code, name, sort_order)
join public.assistance_categories c on c.code = m.cat_code
on conflict (category_id, code) do nothing;

-- ---------------------------------------------------------------------------
-- expense_categories
create table if not exists public.expense_categories (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.expense_categories is 'Categorías de gasto configurables.';

insert into public.expense_categories (code, name, sort_order) values
  ('semillas','Semillas', 10),
  ('fertilizantes','Fertilizantes', 20),
  ('insecticidas','Insecticidas', 30),
  ('fungicidas','Fungicidas', 40),
  ('abonos','Abonos', 50),
  ('jornales','Jornales', 60),
  ('bombeo','Bombeo', 70),
  ('combustible','Combustible', 80),
  ('electricidad','Electricidad', 90),
  ('herramientas','Herramientas', 100),
  ('transporte','Transporte', 110),
  ('otro','Otro', 999)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- buyers
create table if not exists public.buyers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location text null,
  zone_id uuid null references public.zones(id) on delete set null,
  phone text null,
  type text null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.buyers is 'Acopiadores/compradores de excedentes.';

-- ---------------------------------------------------------------------------
-- reference_prices
create table if not exists public.reference_prices (
  id uuid primary key default gen_random_uuid(),
  crop_id uuid not null references public.crops(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete cascade,
  price numeric not null check (price >= 0),
  currency text not null default 'PEN',
  valid_from date not null,
  valid_to date null,
  notes text null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.reference_prices is 'Precios de referencia para el valor estimado del autoconsumo (no es ingreso real).';

-- ---------------------------------------------------------------------------
-- app_settings
create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null default 'null'::jsonb,
  description text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);
comment on table public.app_settings is 'Parámetros de configuración de la aplicación.';

insert into public.app_settings (key, value, description) values
  ('adoption_active_days','30','Días sin actividad para dejar de considerarse adoption_status = active'),
  ('adoption_low_usage_days','60','Días sin actividad para adoption_status = low_usage'),
  ('adoption_needs_support_days','90','Días sin actividad para adoption_status = needs_support')
on conflict (key) do nothing;
