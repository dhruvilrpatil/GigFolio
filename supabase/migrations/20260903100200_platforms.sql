-- =====================================================================
-- 03. Gig platform registry, worker connections, and sync bookkeeping
-- =====================================================================

-- Catalogue of external gig platforms Ignite can ingest from. Publicly readable.
create table public.platforms (
  id              uuid primary key default gen_random_uuid(),
  slug            text not null unique,
  name            text not null,
  category        public.platform_category not null,
  description     text,
  logo_url        text,
  website_url     text,
  countries       text[] not null default '{IN}',
  supports_api    boolean not null default false,
  supported_methods public.connection_method[] not null default '{manual_entry}',
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint platforms_slug_format check (slug ~ '^[a-z0-9][a-z0-9\-]{1,48}$')
);

create index platforms_category_idx on public.platforms (category) where is_active;

-- A worker's account on one external platform. This is what makes the profile portable.
create table public.platform_connections (
  id                     uuid primary key default gen_random_uuid(),
  worker_id              uuid not null references public.profiles (id) on delete cascade,
  platform_id            uuid not null references public.platforms (id) on delete restrict,
  external_worker_id     text,
  external_username      text,
  display_label          text,
  status                 public.connection_status not null default 'pending',
  method                 public.connection_method not null default 'manual_entry',
  -- Reference to a secret held outside this table (Vault key / edge-function secret name).
  -- Platform credentials and OAuth tokens must never be stored in application tables.
  credential_ref         text,
  joined_platform_on     date,
  last_synced_at         timestamptz,
  next_sync_at           timestamptz,
  sync_error             text,
  consecutive_failures   int not null default 0 check (consecutive_failures >= 0),
  is_verified            boolean not null default false,
  verification_method    public.verification_method,
  verified_at            timestamptz,
  metadata               jsonb not null default '{}'::jsonb,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

create unique index platform_connections_worker_platform_key
  on public.platform_connections (worker_id, platform_id, coalesce(external_worker_id, ''));
create index platform_connections_worker_idx on public.platform_connections (worker_id);
create index platform_connections_due_sync_idx
  on public.platform_connections (next_sync_at)
  where status = 'active';

comment on column public.platform_connections.credential_ref is
  'Pointer to a secret stored in Supabase Vault. Never put tokens or passwords in this table.';

-- One row per ingestion run, so a worker can see exactly where their data came from.
create table public.platform_sync_logs (
  id                  uuid primary key default gen_random_uuid(),
  connection_id       uuid not null references public.platform_connections (id) on delete cascade,
  worker_id           uuid not null references public.profiles (id) on delete cascade,
  status              public.connection_status not null default 'syncing',
  trigger_source      text not null default 'scheduled',   -- 'scheduled' | 'manual' | 'webhook'
  started_at          timestamptz not null default now(),
  completed_at        timestamptz,
  engagements_synced  int not null default 0 check (engagements_synced >= 0),
  earnings_synced     int not null default 0 check (earnings_synced >= 0),
  ratings_synced      int not null default 0 check (ratings_synced >= 0),
  error_message       text,
  summary             jsonb not null default '{}'::jsonb
);

create index platform_sync_logs_connection_idx
  on public.platform_sync_logs (connection_id, started_at desc);
