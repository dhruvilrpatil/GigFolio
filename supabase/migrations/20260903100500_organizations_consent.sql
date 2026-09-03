-- =====================================================================
-- 06. Verifiers: organizations, seats, consent, sharing, audit trail
-- =====================================================================

-- Banks, employers, insurers - anyone who evaluates a worker.
create table public.organizations (
  id                   uuid primary key default gen_random_uuid(),
  name                 text not null,
  slug                 text not null unique,
  organization_type    public.organization_type not null default 'other',
  description          text,
  registration_number  text,
  website_url          text,
  logo_url             text,
  contact_email        text,
  contact_phone        text,
  address              text,
  city                 text,
  country              text not null default 'IN',
  verification_status  public.verification_status not null default 'pending',
  is_active            boolean not null default true,
  created_by           uuid references public.profiles (id) on delete set null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),

  constraint organizations_slug_format check (slug ~ '^[a-z0-9][a-z0-9\-]{1,62}$')
);

create index organizations_type_idx on public.organizations (organization_type) where is_active;

-- Deferred foreign keys from the reputation migration.
alter table public.skill_endorsements
  add constraint skill_endorsements_org_fk
  foreign key (endorser_org_id) references public.organizations (id) on delete set null;

alter table public.credentials
  add constraint credentials_issuer_org_fk
  foreign key (issuer_org_id) references public.organizations (id) on delete set null;

-- Seats. A profile can hold seats at several organizations.
create table public.organization_members (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations (id) on delete cascade,
  profile_id       uuid not null references public.profiles (id) on delete cascade,
  role             public.org_member_role not null default 'viewer',
  invited_by       uuid references public.profiles (id) on delete set null,
  joined_at        timestamptz not null default now(),
  is_active        boolean not null default true,

  unique (organization_id, profile_id)
);

create index organization_members_profile_idx
  on public.organization_members (profile_id) where is_active;

-- An organization asking a worker for access. Nothing is read before the worker answers.
create table public.access_requests (
  id                uuid primary key default gen_random_uuid(),
  organization_id   uuid not null references public.organizations (id) on delete cascade,
  worker_id         uuid not null references public.profiles (id) on delete cascade,
  requested_by      uuid references public.profiles (id) on delete set null,
  requested_scopes  public.access_scope[] not null,
  purpose           text not null,
  message           text,
  status            public.request_status not null default 'pending',
  responded_at      timestamptz,
  expires_at        timestamptz not null default (now() + interval '14 days'),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  constraint access_requests_scopes_not_empty check (array_length(requested_scopes, 1) > 0)
);

create index access_requests_worker_idx
  on public.access_requests (worker_id, status, created_at desc);
create index access_requests_org_idx
  on public.access_requests (organization_id, status, created_at desc);

-- The consent record itself. Every organization read is authorised against this table.
create table public.consent_grants (
  id                 uuid primary key default gen_random_uuid(),
  worker_id          uuid not null references public.profiles (id) on delete cascade,
  organization_id    uuid not null references public.organizations (id) on delete cascade,
  access_request_id  uuid references public.access_requests (id) on delete set null,
  scopes             public.access_scope[] not null,
  purpose            text not null,
  status             public.consent_status not null default 'active',
  granted_at         timestamptz not null default now(),
  expires_at         timestamptz,
  revoked_at         timestamptz,
  revoked_reason     text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),

  constraint consent_grants_scopes_not_empty check (array_length(scopes, 1) > 0),
  constraint consent_grants_expiry_after_grant
    check (expires_at is null or expires_at > granted_at),
  constraint consent_grants_revoked_has_timestamp
    check (status <> 'revoked' or revoked_at is not null)
);

-- At most one live grant per worker/organization pair; history is kept via revoked rows.
create unique index consent_grants_active_key
  on public.consent_grants (worker_id, organization_id)
  where status = 'active';
create index consent_grants_org_idx on public.consent_grants (organization_id, status);
create index consent_grants_expiry_idx on public.consent_grants (expires_at)
  where status = 'active' and expires_at is not null;

comment on table public.consent_grants is
  'Worker-controlled authorisation. public.has_consent() reads this table in every organization-facing RLS policy.';

-- A time-boxed link a worker can hand to someone with no Ignite account.
create table public.profile_shares (
  id             uuid primary key default gen_random_uuid(),
  worker_id      uuid not null references public.profiles (id) on delete cascade,
  share_token    text not null unique,
  title          text,
  recipient_name text,
  scopes         public.access_scope[] not null,
  expires_at     timestamptz,
  max_views      int check (max_views > 0),
  view_count     int not null default 0 check (view_count >= 0),
  password_hash  text,
  is_active      boolean not null default true,
  revoked_at     timestamptz,
  created_at     timestamptz not null default now(),

  constraint profile_shares_scopes_not_empty check (array_length(scopes, 1) > 0)
);

create index profile_shares_worker_idx on public.profile_shares (worker_id, created_at desc);
create index profile_shares_active_idx on public.profile_shares (share_token) where is_active;

-- Append-only audit trail: every time anyone touches a worker's data, it lands here.
create table public.access_logs (
  id                 uuid primary key default gen_random_uuid(),
  worker_id          uuid not null references public.profiles (id) on delete cascade,
  actor_profile_id   uuid references public.profiles (id) on delete set null,
  organization_id    uuid references public.organizations (id) on delete set null,
  consent_grant_id   uuid references public.consent_grants (id) on delete set null,
  profile_share_id   uuid references public.profile_shares (id) on delete set null,
  action             public.audit_action not null,
  scopes_accessed    public.access_scope[] not null default '{}',
  resource_type      text,
  resource_id        uuid,
  ip_address         inet,
  user_agent         text,
  metadata           jsonb not null default '{}'::jsonb,
  occurred_at        timestamptz not null default now()
);

create index access_logs_worker_idx on public.access_logs (worker_id, occurred_at desc);
create index access_logs_org_idx on public.access_logs (organization_id, occurred_at desc);

comment on table public.access_logs is
  'Append-only. Workers read their own trail; no policy grants UPDATE or DELETE.';
