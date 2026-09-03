-- =====================================================================
-- 05. Reputation signals: platform ratings, reviews, skills, credentials
-- =====================================================================

-- A point-in-time snapshot of a worker's standing on one platform.
create table public.platform_ratings (
  id                   uuid primary key default gen_random_uuid(),
  worker_id            uuid not null references public.profiles (id) on delete cascade,
  connection_id        uuid references public.platform_connections (id) on delete cascade,
  platform_id          uuid not null references public.platforms (id) on delete restrict,
  rating_value         numeric(4,2) not null check (rating_value >= 0),
  rating_scale         numeric(4,2) not null default 5 check (rating_scale > 0),
  total_reviews        int not null default 0 check (total_reviews >= 0),
  total_jobs           int not null default 0 check (total_jobs >= 0),
  acceptance_rate      numeric(5,2) check (acceptance_rate between 0 and 100),
  completion_rate      numeric(5,2) check (completion_rate between 0 and 100),
  cancellation_rate    numeric(5,2) check (cancellation_rate between 0 and 100),
  on_time_rate         numeric(5,2) check (on_time_rate between 0 and 100),
  tier_label           text,                                -- 'Gold Partner', 'Top Rated', ...
  as_of                date not null default current_date,
  is_verified          boolean not null default false,
  verification_method  public.verification_method,
  metadata             jsonb not null default '{}'::jsonb,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),

  constraint platform_ratings_within_scale check (rating_value <= rating_scale)
);

create unique index platform_ratings_snapshot_key
  on public.platform_ratings (worker_id, platform_id, as_of);
create index platform_ratings_worker_idx on public.platform_ratings (worker_id, as_of desc);

-- Individual customer feedback, where a platform exposes it.
create table public.reviews (
  id                  uuid primary key default gen_random_uuid(),
  worker_id           uuid not null references public.profiles (id) on delete cascade,
  platform_id         uuid not null references public.platforms (id) on delete restrict,
  engagement_id       uuid references public.work_engagements (id) on delete set null,
  external_review_id  text,
  reviewer_name       text,
  rating              numeric(3,2) check (rating >= 0 and rating <= 5),
  comment             text,
  reviewed_at         timestamptz,
  is_verified         boolean not null default false,
  created_at          timestamptz not null default now()
);

create unique index reviews_external_key
  on public.reviews (platform_id, external_review_id) where external_review_id is not null;
create index reviews_worker_idx on public.reviews (worker_id, reviewed_at desc);

-- Controlled skill vocabulary, so skills are comparable across workers.
create table public.skills (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique,
  name        text not null,
  category    public.platform_category,
  description text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),

  constraint skills_slug_format check (slug ~ '^[a-z0-9][a-z0-9\-]{1,48}$')
);

create table public.worker_skills (
  id                   uuid primary key default gen_random_uuid(),
  worker_id            uuid not null references public.profiles (id) on delete cascade,
  skill_id             uuid not null references public.skills (id) on delete cascade,
  proficiency          int not null default 1 check (proficiency between 1 and 5),
  years_of_experience  numeric(4,1) check (years_of_experience >= 0),
  is_primary           boolean not null default false,
  endorsement_count    int not null default 0 check (endorsement_count >= 0),
  verification_status  public.verification_status not null default 'unverified',
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),

  unique (worker_id, skill_id)
);

create index worker_skills_skill_idx on public.worker_skills (skill_id);

-- An endorsement from a person, an organization, or an ingested platform badge.
create table public.skill_endorsements (
  id               uuid primary key default gen_random_uuid(),
  worker_skill_id  uuid not null references public.worker_skills (id) on delete cascade,
  endorser_profile_id  uuid references public.profiles (id) on delete set null,
  endorser_org_id      uuid,   -- FK added in the organizations migration
  platform_id          uuid references public.platforms (id) on delete set null,
  comment          text,
  created_at       timestamptz not null default now(),

  constraint skill_endorsements_has_endorser check (
    endorser_profile_id is not null or endorser_org_id is not null or platform_id is not null
  )
);

create unique index skill_endorsements_unique_person
  on public.skill_endorsements (worker_skill_id, endorser_profile_id)
  where endorser_profile_id is not null;

-- Certifications, licences, background checks — the verifiable paper trail.
create table public.credentials (
  id                   uuid primary key default gen_random_uuid(),
  worker_id            uuid not null references public.profiles (id) on delete cascade,
  credential_type      public.credential_type not null default 'certification',
  title                text not null,
  issuer_name          text not null,
  issuer_org_id        uuid,   -- FK added in the organizations migration
  credential_number    text,
  issued_on            date,
  expires_on           date,
  credential_url       text,
  storage_path         text,
  verification_status  public.verification_status not null default 'pending',
  verification_method  public.verification_method,
  verified_at          timestamptz,
  verified_by          uuid references public.profiles (id) on delete set null,
  metadata             jsonb not null default '{}'::jsonb,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),

  constraint credentials_expiry_after_issue
    check (expires_on is null or issued_on is null or expires_on > issued_on)
);

create index credentials_worker_idx on public.credentials (worker_id);
create index credentials_expiry_idx on public.credentials (expires_on)
  where expires_on is not null and verification_status = 'verified';
