-- =====================================================================
-- 12. PostGIS + pgvector, and the enums for civic service requests
--
-- Both extensions live in the `extensions` schema (Supabase convention).
-- Types and operator classes are therefore schema-qualified everywhere,
-- so nothing here depends on search_path being set a particular way.
-- =====================================================================

create extension if not exists postgis with schema extensions;
create extension if not exists vector  with schema extensions;

-- halfvec (2-byte floats) needs pgvector >= 0.7.0.
do $$
begin
  if to_regtype('extensions.halfvec') is null then
    raise exception 'pgvector is too old for halfvec - upgrade the extension to >= 0.7.0';
  end if;
end;
$$;

create type public.service_request_status as enum (
  'open', 'triaged', 'assigned', 'in_progress',
  'resolved', 'closed', 'rejected', 'duplicate'
);

create type public.service_request_priority as enum ('low', 'medium', 'high', 'critical');

create type public.service_request_category as enum (
  'pothole', 'streetlight', 'garbage', 'water_supply', 'sewage_drainage',
  'traffic_signal', 'illegal_dumping', 'encroachment', 'stray_animals',
  'noise', 'public_safety', 'parks_trees', 'other'
);

create type public.cluster_status as enum ('active', 'monitoring', 'resolved', 'archived');

-- Deliberately NOT named audit_action: that enum already exists in this
-- database for the consent audit trail and means something different.
create type public.audit_operation as enum ('insert', 'update', 'delete');
