-- ============================================================================
-- AgroApp · PARTE 1 — ENUMS
-- Idempotente. Ejecutar primero.
-- ============================================================================

create extension if not exists pgcrypto;

do $$ begin create type public.user_role as enum ('farmer','technician','supervisor','admin'); exception when duplicate_object then null; end $$;
do $$ begin create type public.user_status as enum ('active','inactive','suspended'); exception when duplicate_object then null; end $$;
do $$ begin create type public.unit_category as enum ('weight','volume','container','productive','area','labor','irrigation','other'); exception when duplicate_object then null; end $$;
do $$ begin create type public.incident_status as enum ('reported','under_review','visit_scheduled','attended','closed'); exception when duplicate_object then null; end $$;
do $$ begin create type public.priority_level as enum ('low','medium','high'); exception when duplicate_object then null; end $$;
do $$ begin create type public.assistance_provider as enum ('AIDER','SENASA','OTHER'); exception when duplicate_object then null; end $$;
do $$ begin create type public.assistance_status as enum ('scheduled','completed','cancelled'); exception when duplicate_object then null; end $$;
do $$ begin create type public.reminder_status as enum ('pending','completed','overdue'); exception when duplicate_object then null; end $$;
do $$ begin create type public.energy_type as enum ('fuel','electricity','other'); exception when duplicate_object then null; end $$;
do $$ begin create type public.residue_destination as enum ('compost','other_use','not_used'); exception when duplicate_object then null; end $$;
do $$ begin create type public.adoption_status as enum ('active','low_usage','needs_support','inactive'); exception when duplicate_object then null; end $$;
do $$ begin create type public.document_kind as enum ('assistance_photo','external_sheet','other'); exception when duplicate_object then null; end $$;
