-- =====================================================================
-- 13. Core tables: clusters, service_requests, issue_embeddings, audit_logs
--     with the four-index strategy (GiST / HNSW / B-Tree / BRIN).
-- =====================================================================

-- clusters is created first: service_requests carries an FK to it.
create table public.clusters (
  id                 uuid primary key default gen_random_uuid(),
  label              text,
  category           public.service_request_category not null,
  status             public.cluster_status not null default 'active',
  priority           public.service_request_priority not null default 'medium',
  centroid           extensions.geography(Point, 4326),
  hull               extensions.geography(Polygon, 4326),
  member_count       integer not null default 0 check (member_count >= 0),
  first_reported_at  timestamptz,
  last_reported_at   timestamptz,
  -- The DBSCAN parameters this cluster was produced with, so a result is
  -- reproducible and two clusters built under different settings are
  -- distinguishable.
  algorithm          text not null default 'ST_ClusterDBSCAN',
  eps_meters         numeric(10,2) check (eps_meters > 0),
  min_points         integer check (min_points > 0),
  computed_at        timestamptz not null default now(),
  metadata           jsonb not null default '{}'::jsonb,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),

  constraint clusters_window_order
    check (last_reported_at is null or first_reported_at is null
           or last_reported_at >= first_reported_at)
);

create sequence public.service_request_ticket_seq;

create table public.service_requests (
  id             uuid primary key default gen_random_uuid(),
  ticket_number  text not null unique
                 default 'SR-' || to_char(now(), 'YYYY') || '-'
                         || lpad(nextval('public.service_request_ticket_seq')::text, 6, '0'),
  reporter_id    uuid references public.profiles (id) on delete set null,
  assigned_to    uuid references public.profiles (id) on delete set null,
  cluster_id     uuid references public.clusters (id) on delete set null,
  duplicate_of   uuid references public.service_requests (id) on delete set null,

  category       public.service_request_category not null,
  subcategory    text,
  title          text not null,
  description    text,
  status         public.service_request_status not null default 'open',
  priority       public.service_request_priority not null default 'medium',

  -- geography(Point,4326): metres-correct distance maths without picking a
  -- projection. ST_DWithin on this column uses the GiST index below.
  location       extensions.geography(Point, 4326) not null,
  address        text,
  ward           text,
  city           text,
  postal_code    text,

  media_paths    text[] not null default '{}',
  source         text not null default 'app',
  upvotes        integer not null default 0 check (upvotes >= 0),

  reported_at      timestamptz not null default now(),
  acknowledged_at  timestamptz,
  resolved_at      timestamptz,
  sla_due_at       timestamptz,

  metadata       jsonb not null default '{}'::jsonb,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  constraint service_requests_not_own_duplicate check (duplicate_of is null or duplicate_of <> id),
  constraint service_requests_duplicate_needs_target
    check (status <> 'duplicate' or duplicate_of is not null),
  constraint service_requests_resolved_after_reported
    check (resolved_at is null or resolved_at >= reported_at),
  constraint service_requests_title_not_blank check (length(btrim(title)) > 0)
);

comment on column public.service_requests.location is
  'geography(Point,4326). Use ST_DWithin(location, point, metres) - it is index-backed and metre-accurate.';

-- One embedding per request; the unique FK is what makes it 1:1.
create table public.issue_embeddings (
  id                  uuid primary key default gen_random_uuid(),
  service_request_id  uuid not null unique
                      references public.service_requests (id) on delete cascade,
  -- halfvec(768): half the storage and index size of vector(768) at
  -- negligible recall cost, which is what makes HNSW cheap to keep in RAM.
  embedding           extensions.halfvec(768) not null,
  model               text not null default 'text-embedding-004',
  dimensions          smallint not null default 768 check (dimensions = 768),
  source_text         text,
  content_hash        text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create table public.audit_logs (
  id              uuid primary key default gen_random_uuid(),
  table_name      text not null,
  record_id       uuid,
  operation       public.audit_operation not null,
  actor_id        uuid references public.profiles (id) on delete set null,
  old_data        jsonb,
  new_data        jsonb,
  changed_fields  text[] not null default '{}',
  ip_address      inet,
  occurred_at     timestamptz not null default now()
);

-- =====================================================================
-- Indexes
-- =====================================================================

-- ---- GiST: geographic queries ------------------------------------------
create index service_requests_location_gist
  on public.service_requests using gist (location);

-- Hotspot and map-viewport queries only ever look at live requests, so a
-- partial GiST index keeps the hot index far smaller than the table.
create index service_requests_location_open_gist
  on public.service_requests using gist (location)
  where status in ('open', 'triaged', 'assigned', 'in_progress');

create index clusters_centroid_gist
  on public.clusters using gist (centroid);

-- ---- HNSW: vector similarity -------------------------------------------
-- m = 16 edges per node, ef_construction = 64 candidates during build.
-- halfvec_cosine_ops is schema-qualified so resolution never depends on
-- the caller's search_path.
create index issue_embeddings_hnsw
  on public.issue_embeddings
  using hnsw (embedding extensions.halfvec_cosine_ops)
  with (m = 16, ef_construction = 64);

-- ---- B-Tree: clusters and the usual lookups ----------------------------
create index clusters_category_status_btree on public.clusters (category, status);
create index clusters_status_recent_btree
  on public.clusters (status, last_reported_at desc nulls last);
create index clusters_member_count_btree on public.clusters (member_count desc);
create index clusters_computed_at_btree on public.clusters (computed_at desc);

create index service_requests_cluster_btree on public.service_requests (cluster_id)
  where cluster_id is not null;
create index service_requests_status_category_btree
  on public.service_requests (status, category);
create index service_requests_reported_at_btree on public.service_requests (reported_at desc);
create index service_requests_reporter_btree on public.service_requests (reporter_id)
  where reporter_id is not null;
create index service_requests_assigned_btree on public.service_requests (assigned_to)
  where assigned_to is not null;
create index service_requests_sla_btree on public.service_requests (sla_due_at)
  where status not in ('resolved', 'closed', 'rejected', 'duplicate');

-- ---- BRIN: audit timestamps --------------------------------------------
-- audit_logs is append-only and physically ordered by time, which is exactly
-- the correlation BRIN exploits: a few KB of index instead of hundreds of MB.
create index audit_logs_occurred_at_brin
  on public.audit_logs using brin (occurred_at)
  with (pages_per_range = 64, autosummarize = on);

create index audit_logs_record_btree on public.audit_logs (table_name, record_id);
create index audit_logs_actor_btree on public.audit_logs (actor_id, occurred_at desc)
  where actor_id is not null;

-- ---- keep updated_at fresh (reuses the trigger fn from migration 08) ----
create trigger set_updated_at before update on public.clusters
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.service_requests
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.issue_embeddings
  for each row execute function public.set_updated_at();
