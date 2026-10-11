-- GeoJSON-style polygon for a parcel: {"type":"Polygon","coordinates":[[[lng,lat],...]]}. Optional; latitude/longitude stay as the centre point.
alter table public.parcels add column if not exists geometry jsonb;
alter table public.parcels drop constraint if exists parcels_geometry_is_polygon;
alter table public.parcels add constraint parcels_geometry_is_polygon
  check (geometry is null or (jsonb_typeof(geometry) = 'object' and geometry->>'type' = 'Polygon' and jsonb_typeof(geometry->'coordinates') = 'array'));
comment on column public.parcels.geometry is 'Polígono GeoJSON del terreno (lng,lat). latitude/longitude = centro.';
