-- ============================================================================
-- AgroApp · PARTE 5 — SEGURIDAD (RLS)
-- RLS en TODAS las tablas de public. Políticas por rol vía helpers SECURITY
-- DEFINER (sin subconsultas directas a tablas con RLS → sin recursión).
-- Sin políticas DELETE salvo admin: el resto usa soft delete.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Activar RLS en todas las tablas
do $$
declare t text;
begin
  foreach t in array array[
    'zones','communities','crops','units','unit_equivalences','products','product_units',
    'activity_types','activity_type_units','crop_harvest_units','pruning_types','symptom_types',
    'assistance_categories','assistance_subtypes','expense_categories','buyers','reference_prices',
    'app_settings','profiles','user_zones','farmers','parcels','technician_parcels','crop_cycles',
    'activities','expenses','incidents','incident_photos','incident_status_history',
    'technical_assistance','assistance_documents','recommendations','recommendation_confirmations',
    'reminders','harvests','surplus_sales','residue_management','notifications','device_tokens',
    'audit_logs','sync_log'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Catálogos y de referencia: SELECT para authenticated, ALL para admin
do $$
declare t text;
begin
  foreach t in array array[
    'zones','communities','crops','units','unit_equivalences','products','product_units',
    'activity_types','activity_type_units','crop_harvest_units','pruning_types','symptom_types',
    'assistance_categories','assistance_subtypes','expense_categories','buyers','reference_prices',
    'app_settings'
  ]
  loop
    execute format('drop policy if exists %I on public.%I', t||'_select_auth', t);
    execute format('create policy %I on public.%I for select to authenticated using (true)', t||'_select_auth', t);
    execute format('drop policy if exists %I on public.%I', t||'_admin_all', t);
    execute format('create policy %I on public.%I for all to authenticated using (public.app_role() = ''admin'') with check (public.app_role() = ''admin'')', t||'_admin_all', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- profiles
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (public.can_view_profile(id));

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists profiles_admin_all on public.profiles;
create policy profiles_admin_all on public.profiles for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- user_zones
drop policy if exists user_zones_select on public.user_zones;
create policy user_zones_select on public.user_zones for select to authenticated
  using (user_id = auth.uid() or public.app_role() = 'admin');

drop policy if exists user_zones_admin_all on public.user_zones;
create policy user_zones_admin_all on public.user_zones for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- farmers
drop policy if exists farmers_select on public.farmers;
create policy farmers_select on public.farmers for select to authenticated
  using (public.can_access_farmer(id));

drop policy if exists farmers_admin_all on public.farmers;
create policy farmers_admin_all on public.farmers for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- technician_parcels
drop policy if exists tech_parcels_select on public.technician_parcels;
create policy tech_parcels_select on public.technician_parcels for select to authenticated
  using (technician_id = auth.uid() or public.app_role() = 'admin');

drop policy if exists tech_parcels_admin_all on public.technician_parcels;
create policy tech_parcels_admin_all on public.technician_parcels for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- parcels
drop policy if exists parcels_select on public.parcels;
create policy parcels_select on public.parcels for select to authenticated
  using (public.can_access_parcel(id));

drop policy if exists parcels_insert on public.parcels;
create policy parcels_insert on public.parcels for insert to authenticated
  with check (
    public.app_role() = 'admin'
    or (public.app_role() = 'farmer' and farmer_id = public.current_farmer_id())
    or (public.app_role() in ('technician','supervisor') and public.has_zone_access(zone_id))
  );

drop policy if exists parcels_admin_all on public.parcels;
create policy parcels_admin_all on public.parcels for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- crop_cycles
drop policy if exists crop_cycles_select on public.crop_cycles;
create policy crop_cycles_select on public.crop_cycles for select to authenticated
  using (public.can_access_parcel(parcel_id));

drop policy if exists crop_cycles_insert on public.crop_cycles;
create policy crop_cycles_insert on public.crop_cycles for insert to authenticated
  with check (
    public.app_role() = 'admin'
    or (public.app_role() = 'farmer' and public.can_access_parcel(parcel_id))
    or (public.app_role() in ('technician','supervisor') and public.can_access_parcel(parcel_id))
  );

drop policy if exists crop_cycles_admin_all on public.crop_cycles;
create policy crop_cycles_admin_all on public.crop_cycles for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- activities (append-only para farmer)
drop policy if exists activities_select on public.activities;
create policy activities_select on public.activities for select to authenticated
  using (public.can_access_cycle(crop_cycle_id));

drop policy if exists activities_insert on public.activities;
create policy activities_insert on public.activities for insert to authenticated
  with check (public.app_role() in ('farmer','technician','supervisor','admin') and public.can_access_cycle(crop_cycle_id));

drop policy if exists activities_admin_all on public.activities;
create policy activities_admin_all on public.activities for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- expenses
drop policy if exists expenses_select on public.expenses;
create policy expenses_select on public.expenses for select to authenticated
  using (public.can_access_parcel(parcel_id));

drop policy if exists expenses_insert on public.expenses;
create policy expenses_insert on public.expenses for insert to authenticated
  with check (public.app_role() in ('farmer','technician','supervisor','admin') and public.can_access_parcel(parcel_id));

drop policy if exists expenses_admin_all on public.expenses;
create policy expenses_admin_all on public.expenses for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- harvests
drop policy if exists harvests_select on public.harvests;
create policy harvests_select on public.harvests for select to authenticated
  using (public.can_access_parcel(parcel_id));

drop policy if exists harvests_insert on public.harvests;
create policy harvests_insert on public.harvests for insert to authenticated
  with check (public.app_role() in ('farmer','technician','supervisor','admin') and public.can_access_parcel(parcel_id));

drop policy if exists harvests_admin_all on public.harvests;
create policy harvests_admin_all on public.harvests for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- surplus_sales
drop policy if exists surplus_sales_select on public.surplus_sales;
create policy surplus_sales_select on public.surplus_sales for select to authenticated
  using (public.can_access_harvest(harvest_id));

drop policy if exists surplus_sales_insert on public.surplus_sales;
create policy surplus_sales_insert on public.surplus_sales for insert to authenticated
  with check (public.app_role() in ('farmer','technician','supervisor','admin') and public.can_access_harvest(harvest_id));

drop policy if exists surplus_sales_admin_all on public.surplus_sales;
create policy surplus_sales_admin_all on public.surplus_sales for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- residue_management
drop policy if exists residue_select on public.residue_management;
create policy residue_select on public.residue_management for select to authenticated
  using (public.can_access_harvest(harvest_id));

drop policy if exists residue_insert on public.residue_management;
create policy residue_insert on public.residue_management for insert to authenticated
  with check (public.app_role() in ('farmer','technician','supervisor','admin') and public.can_access_harvest(harvest_id));

drop policy if exists residue_admin_all on public.residue_management;
create policy residue_admin_all on public.residue_management for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- incidents
drop policy if exists incidents_select on public.incidents;
create policy incidents_select on public.incidents for select to authenticated
  using (public.can_access_parcel(parcel_id));

drop policy if exists incidents_insert on public.incidents;
create policy incidents_insert on public.incidents for insert to authenticated
  with check (
    public.app_role() = 'admin'
    or (public.app_role() = 'farmer' and farmer_id = public.current_farmer_id() and public.can_access_parcel(parcel_id))
    or (public.app_role() in ('technician','supervisor') and public.can_access_parcel(parcel_id))
  );

drop policy if exists incidents_update on public.incidents;
create policy incidents_update on public.incidents for update to authenticated
  using (public.app_role() in ('technician','supervisor','admin') and public.can_access_parcel(parcel_id))
  with check (public.app_role() in ('technician','supervisor','admin') and public.can_access_parcel(parcel_id));

drop policy if exists incidents_admin_all on public.incidents;
create policy incidents_admin_all on public.incidents for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- incident_photos
drop policy if exists incident_photos_select on public.incident_photos;
create policy incident_photos_select on public.incident_photos for select to authenticated
  using (public.can_access_incident(incident_id));

drop policy if exists incident_photos_insert on public.incident_photos;
create policy incident_photos_insert on public.incident_photos for insert to authenticated
  with check (public.app_role() in ('farmer','technician','supervisor','admin') and public.can_access_incident(incident_id));

drop policy if exists incident_photos_admin_all on public.incident_photos;
create policy incident_photos_admin_all on public.incident_photos for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- incident_status_history
drop policy if exists incident_hist_select on public.incident_status_history;
create policy incident_hist_select on public.incident_status_history for select to authenticated
  using (public.can_access_incident(incident_id));

drop policy if exists incident_hist_admin_all on public.incident_status_history;
create policy incident_hist_admin_all on public.incident_status_history for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- technical_assistance
drop policy if exists assistance_select on public.technical_assistance;
create policy assistance_select on public.technical_assistance for select to authenticated
  using (public.can_access_parcel(parcel_id));

drop policy if exists assistance_insert on public.technical_assistance;
create policy assistance_insert on public.technical_assistance for insert to authenticated
  with check (
    public.app_role() = 'admin'
    or (public.app_role() = 'farmer' and farmer_id = public.current_farmer_id() and provider <> 'AIDER')
    or (public.app_role() in ('technician','supervisor') and public.can_access_parcel(parcel_id))
  );

drop policy if exists assistance_update on public.technical_assistance;
create policy assistance_update on public.technical_assistance for update to authenticated
  using (public.app_role() in ('technician','supervisor','admin') and public.can_access_parcel(parcel_id))
  with check (public.app_role() in ('technician','supervisor','admin') and public.can_access_parcel(parcel_id));

drop policy if exists assistance_admin_all on public.technical_assistance;
create policy assistance_admin_all on public.technical_assistance for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- assistance_documents
drop policy if exists assistance_docs_select on public.assistance_documents;
create policy assistance_docs_select on public.assistance_documents for select to authenticated
  using (public.can_access_assistance(assistance_id));

drop policy if exists assistance_docs_insert on public.assistance_documents;
create policy assistance_docs_insert on public.assistance_documents for insert to authenticated
  with check (public.app_role() in ('farmer','technician','supervisor','admin') and public.can_access_assistance(assistance_id));

drop policy if exists assistance_docs_admin_all on public.assistance_documents;
create policy assistance_docs_admin_all on public.assistance_documents for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- recommendations
drop policy if exists recommendations_select on public.recommendations;
create policy recommendations_select on public.recommendations for select to authenticated
  using (public.can_access_parcel(parcel_id));

drop policy if exists recommendations_insert on public.recommendations;
create policy recommendations_insert on public.recommendations for insert to authenticated
  with check (public.app_role() in ('technician','supervisor','admin') and public.can_access_parcel(parcel_id));

drop policy if exists recommendations_update on public.recommendations;
create policy recommendations_update on public.recommendations for update to authenticated
  using (public.app_role() in ('technician','supervisor','admin') and public.can_access_parcel(parcel_id))
  with check (public.app_role() in ('technician','supervisor','admin') and public.can_access_parcel(parcel_id));

drop policy if exists recommendations_admin_all on public.recommendations;
create policy recommendations_admin_all on public.recommendations for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- recommendation_confirmations
drop policy if exists reco_confirm_select on public.recommendation_confirmations;
create policy reco_confirm_select on public.recommendation_confirmations for select to authenticated
  using (public.can_access_farmer(farmer_id));

drop policy if exists reco_confirm_insert on public.recommendation_confirmations;
create policy reco_confirm_insert on public.recommendation_confirmations for insert to authenticated
  with check (public.app_role() in ('farmer','technician','supervisor','admin') and public.can_access_farmer(farmer_id));

drop policy if exists reco_confirm_admin_all on public.recommendation_confirmations;
create policy reco_confirm_admin_all on public.recommendation_confirmations for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- reminders (farmer puede actualizar/completar los propios)
drop policy if exists reminders_select on public.reminders;
create policy reminders_select on public.reminders for select to authenticated
  using (public.can_access_farmer(farmer_id));

drop policy if exists reminders_insert on public.reminders;
create policy reminders_insert on public.reminders for insert to authenticated
  with check (public.app_role() in ('technician','supervisor','admin') and public.can_access_farmer(farmer_id));

drop policy if exists reminders_update on public.reminders;
create policy reminders_update on public.reminders for update to authenticated
  using (public.can_access_farmer(farmer_id))
  with check (public.app_role() in ('farmer','technician','supervisor','admin') and public.can_access_farmer(farmer_id));

drop policy if exists reminders_admin_all on public.reminders;
create policy reminders_admin_all on public.reminders for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- notifications
drop policy if exists notifications_select on public.notifications;
create policy notifications_select on public.notifications for select to authenticated
  using (user_id = auth.uid() or public.app_role() = 'admin');

drop policy if exists notifications_update on public.notifications;
create policy notifications_update on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists notifications_admin_all on public.notifications;
create policy notifications_admin_all on public.notifications for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- device_tokens
drop policy if exists device_tokens_select on public.device_tokens;
create policy device_tokens_select on public.device_tokens for select to authenticated
  using (user_id = auth.uid() or public.app_role() = 'admin');

drop policy if exists device_tokens_insert on public.device_tokens;
create policy device_tokens_insert on public.device_tokens for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists device_tokens_update on public.device_tokens;
create policy device_tokens_update on public.device_tokens for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists device_tokens_admin_all on public.device_tokens;
create policy device_tokens_admin_all on public.device_tokens for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- audit_logs (supervisor solo lectura; admin todo)
drop policy if exists audit_logs_select on public.audit_logs;
create policy audit_logs_select on public.audit_logs for select to authenticated
  using (public.app_role() in ('supervisor','admin'));

drop policy if exists audit_logs_admin_all on public.audit_logs;
create policy audit_logs_admin_all on public.audit_logs for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ---------------------------------------------------------------------------
-- sync_log (supervisor lectura; authenticated insert propio vía sync_batch; admin todo)
drop policy if exists sync_log_select on public.sync_log;
create policy sync_log_select on public.sync_log for select to authenticated
  using (public.app_role() in ('supervisor','admin'));

drop policy if exists sync_log_insert on public.sync_log;
create policy sync_log_insert on public.sync_log for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists sync_log_admin_all on public.sync_log;
create policy sync_log_admin_all on public.sync_log for all to authenticated
  using (public.app_role() = 'admin') with check (public.app_role() = 'admin');
