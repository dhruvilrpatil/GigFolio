-- =====================================================================
-- 07. Derived trust: reputation scores, verification records,
--     income-verification reports, notifications
-- =====================================================================

-- The portable, cross-platform reputation score. History is kept; is_current marks the live row.
create table public.reputation_scores (
  id             uuid primary key default gen_random_uuid(),
  worker_id      uuid not null references public.profiles (id) on delete cascade,
  score          numeric(6,2) not null check (score between 0 and 1000),
  score_band     text not null default 'bronze'
                 check (score_band in ('bronze', 'silver', 'gold', 'platinum')),
  -- Weighted sub-scores, each 0-100, so a lender can see *why* the score is what it is.
  identity_score      numeric(5,2) check (identity_score between 0 and 100),
  experience_score    numeric(5,2) check (experience_score between 0 and 100),
  reliability_score   numeric(5,2) check (reliability_score between 0 and 100),
  earnings_score      numeric(5,2) check (earnings_score between 0 and 100),
  rating_score        numeric(5,2) check (rating_score between 0 and 100),
  components     jsonb not null default '{}'::jsonb,   -- full breakdown + inputs used
  model_version  text not null default 'v1',
  is_current     boolean not null default true,
  computed_at    timestamptz not null default now(),
  valid_until    timestamptz
);

create unique index reputation_scores_current_key
  on public.reputation_scores (worker_id, model_version) where is_current;
create index reputation_scores_history_idx
  on public.reputation_scores (worker_id, computed_at desc);

comment on column public.reputation_scores.components is
  'Explainability payload: the inputs and weights behind the score, for dispute handling.';

-- Cross-cutting evidence log: which entity was verified, by whom, how.
create table public.verification_records (
  id                   uuid primary key default gen_random_uuid(),
  worker_id            uuid not null references public.profiles (id) on delete cascade,
  entity_type          text not null
                       check (entity_type in ('profile', 'identity_document', 'kyc',
                                              'platform_connection', 'work_engagement',
                                              'earnings', 'platform_rating', 'worker_skill',
                                              'credential')),
  entity_id            uuid,
  status               public.verification_status not null default 'pending',
  method               public.verification_method not null,
  verified_by_profile  uuid references public.profiles (id) on delete set null,
  verified_by_org      uuid references public.organizations (id) on delete set null,
  evidence_url         text,
  notes                text,
  verified_at          timestamptz,
  expires_at           timestamptz,
  created_at           timestamptz not null default now()
);

create index verification_records_worker_idx
  on public.verification_records (worker_id, created_at desc);
create index verification_records_entity_idx
  on public.verification_records (entity_type, entity_id);

-- A frozen, hash-stamped snapshot handed to a bank or employer.
-- Tamper-evident: content_hash covers the summary at generation time.
create table public.income_verification_reports (
  id                 uuid primary key default gen_random_uuid(),
  worker_id          uuid not null references public.profiles (id) on delete cascade,
  organization_id    uuid references public.organizations (id) on delete set null,
  consent_grant_id   uuid references public.consent_grants (id) on delete set null,
  report_number      text not null unique,
  period_start       date not null,
  period_end         date not null,
  scopes_included    public.access_scope[] not null default '{}',
  summary            jsonb not null default '{}'::jsonb,
  storage_path       text,
  content_hash       text,
  generated_by       uuid references public.profiles (id) on delete set null,
  generated_at       timestamptz not null default now(),
  expires_at         timestamptz,

  constraint income_reports_period_order check (period_end >= period_start)
);

create index income_reports_worker_idx
  on public.income_verification_reports (worker_id, generated_at desc);
create index income_reports_org_idx
  on public.income_verification_reports (organization_id, generated_at desc);

create table public.notifications (
  id           uuid primary key default gen_random_uuid(),
  profile_id   uuid not null references public.profiles (id) on delete cascade,
  type         text not null,
  title        text not null,
  body         text,
  link_url     text,
  is_read      boolean not null default false,
  read_at      timestamptz,
  metadata     jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);

create index notifications_unread_idx
  on public.notifications (profile_id, created_at desc) where not is_read;
