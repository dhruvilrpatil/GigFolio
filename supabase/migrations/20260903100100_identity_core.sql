-- =====================================================================
-- 02. Core identity: profiles, worker profiles, ID documents, KYC
-- =====================================================================

-- One row per auth.users row. The root of every identity in the system.
create table public.profiles (
  id                  uuid primary key references auth.users (id) on delete cascade,
  role                public.user_role not null default 'worker',
  full_name           text not null default '',
  display_name        text,
  email               text,
  phone               text,
  avatar_url          text,
  date_of_birth       date,
  gender              text,
  bio                 text,
  address_line1       text,
  address_line2       text,
  city                text,
  state               text,
  postal_code         text,
  country             text not null default 'IN',
  preferred_language  text not null default 'en',
  kyc_status          public.kyc_status not null default 'not_started',
  is_active           boolean not null default true,
  last_seen_at        timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  constraint profiles_dob_past check (date_of_birth is null or date_of_birth < current_date),
  constraint profiles_phone_format check (phone is null or phone ~ '^\+?[0-9 \-]{7,20}$')
);

create unique index profiles_email_key on public.profiles (lower(email)) where email is not null;
create index profiles_role_idx on public.profiles (role);
create index profiles_city_idx on public.profiles (lower(city)) where city is not null;

comment on table public.profiles is
  'Root identity record, 1:1 with auth.users. Created automatically by handle_new_user().';

-- Worker-specific extension of a profile.
create table public.worker_profiles (
  profile_id            uuid primary key references public.profiles (id) on delete cascade,
  headline              text,
  years_of_experience   numeric(4,1) check (years_of_experience >= 0 and years_of_experience <= 70),
  primary_category      public.platform_category,
  categories            public.platform_category[] not null default '{}',
  vehicle_type          text,
  service_radius_km     numeric(6,2) check (service_radius_km >= 0),
  expected_hourly_rate  numeric(12,2) check (expected_hourly_rate >= 0),
  currency              char(3) not null default 'INR',
  available_for_work    boolean not null default true,
  -- Shareable public handle, e.g. ignite.app/w/ravi-kumar-8f2a
  public_slug           text unique,
  is_public             boolean not null default false,
  onboarding_completed  boolean not null default false,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),

  constraint worker_profiles_slug_format
    check (public_slug is null or public_slug ~ '^[a-z0-9][a-z0-9\-]{2,62}$')
);

create index worker_profiles_category_idx on public.worker_profiles (primary_category);
create index worker_profiles_public_idx on public.worker_profiles (is_public) where is_public;

comment on column public.worker_profiles.public_slug is
  'Optional vanity handle for the worker''s public profile page.';

-- Government / platform ID documents. Raw numbers are never stored in clear text.
create table public.identity_documents (
  id                       uuid primary key default gen_random_uuid(),
  worker_id                uuid not null references public.profiles (id) on delete cascade,
  document_type            public.document_type not null,
  document_number_masked   text,          -- e.g. 'XXXXXXXX4821'
  document_number_hash     text,          -- sha256(number || pepper), for dedupe only
  issuing_authority        text,
  issuing_country          text not null default 'IN',
  issued_on                date,
  expires_on               date,
  storage_path             text,          -- object key in the private 'identity-documents' bucket
  verification_status      public.verification_status not null default 'pending',
  verification_method      public.verification_method,
  verified_at              timestamptz,
  verified_by              uuid references public.profiles (id) on delete set null,
  rejection_reason         text,
  metadata                 jsonb not null default '{}'::jsonb,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),

  constraint identity_documents_expiry_after_issue
    check (expires_on is null or issued_on is null or expires_on > issued_on)
);

create index identity_documents_worker_idx on public.identity_documents (worker_id);
create index identity_documents_status_idx on public.identity_documents (verification_status);
create unique index identity_documents_hash_key
  on public.identity_documents (document_type, document_number_hash)
  where document_number_hash is not null;

comment on column public.identity_documents.document_number_hash is
  'Hash only. Storing raw ID numbers is a compliance risk and is deliberately unsupported.';

-- Each attempt at verifying a worker's legal identity through a KYC provider.
create table public.kyc_verifications (
  id                uuid primary key default gen_random_uuid(),
  worker_id         uuid not null references public.profiles (id) on delete cascade,
  provider          text not null,                       -- 'digilocker', 'signzy', 'manual', ...
  provider_ref      text,                                -- provider-side transaction id
  method            public.verification_method not null default 'third_party_kyc',
  status            public.kyc_status not null default 'pending',
  matched_name      text,
  match_score       numeric(5,2) check (match_score between 0 and 100),
  failure_reason    text,
  verified_at       timestamptz,
  expires_at        timestamptz,
  response_summary  jsonb not null default '{}'::jsonb,  -- redacted provider payload
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index kyc_verifications_worker_idx on public.kyc_verifications (worker_id, created_at desc);
create unique index kyc_verifications_provider_ref_key
  on public.kyc_verifications (provider, provider_ref) where provider_ref is not null;
