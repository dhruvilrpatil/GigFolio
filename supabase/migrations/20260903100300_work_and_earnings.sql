-- =====================================================================
-- 04. Unified work history, earnings, and pre-aggregated summaries
-- =====================================================================

-- One completed (or attempted) piece of work, normalised across every platform.
create table public.work_engagements (
  id                     uuid primary key default gen_random_uuid(),
  worker_id              uuid not null references public.profiles (id) on delete cascade,
  connection_id          uuid references public.platform_connections (id) on delete set null,
  platform_id            uuid not null references public.platforms (id) on delete restrict,
  external_engagement_id text,
  title                  text not null,
  description            text,
  category               public.platform_category,
  status                 public.engagement_status not null default 'completed',
  started_at             timestamptz,
  completed_at           timestamptz,
  duration_minutes       int check (duration_minutes >= 0),
  distance_km            numeric(10,2) check (distance_km >= 0),
  pickup_city            text,
  drop_city              text,
  client_name            text,
  client_rating          numeric(3,2) check (client_rating >= 0 and client_rating <= 5),
  gross_amount           numeric(14,2) check (gross_amount >= 0),
  currency               char(3) not null default 'INR',
  is_verified            boolean not null default false,
  verification_method    public.verification_method,
  metadata               jsonb not null default '{}'::jsonb,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),

  constraint work_engagements_completed_after_start
    check (completed_at is null or started_at is null or completed_at >= started_at)
);

-- Idempotent re-sync: the same external record can never be imported twice.
create unique index work_engagements_external_key
  on public.work_engagements (connection_id, external_engagement_id)
  where external_engagement_id is not null;
create index work_engagements_worker_time_idx
  on public.work_engagements (worker_id, completed_at desc nulls last);
create index work_engagements_platform_idx on public.work_engagements (platform_id);
create index work_engagements_status_idx on public.work_engagements (worker_id, status);

comment on table public.work_engagements is
  'Platform-agnostic work history. A delivery, a ride, a home visit and a freelance milestone all land here.';

-- Money. Split by type so a lender can distinguish stable base pay from volatile incentives.
create table public.earnings (
  id                   uuid primary key default gen_random_uuid(),
  worker_id            uuid not null references public.profiles (id) on delete cascade,
  connection_id        uuid references public.platform_connections (id) on delete set null,
  platform_id          uuid not null references public.platforms (id) on delete restrict,
  engagement_id        uuid references public.work_engagements (id) on delete set null,
  external_earning_id  text,
  earning_type         public.earning_type not null default 'base_pay',
  amount               numeric(14,2) not null,
  currency             char(3) not null default 'INR',
  earned_on            date not null,
  payout_status        public.payout_status not null default 'pending',
  payout_date          date,
  payout_reference     text,
  is_verified          boolean not null default false,
  verification_method  public.verification_method,
  metadata             jsonb not null default '{}'::jsonb,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),

  -- Penalties and refunds are negative; everything else must be positive.
  constraint earnings_amount_sign check (
    (earning_type in ('penalty', 'adjustment', 'refund') and amount <> 0)
    or (earning_type not in ('penalty', 'adjustment', 'refund') and amount >= 0)
  )
);

create unique index earnings_external_key
  on public.earnings (connection_id, external_earning_id)
  where external_earning_id is not null;
create index earnings_worker_date_idx on public.earnings (worker_id, earned_on desc);
create index earnings_platform_date_idx on public.earnings (platform_id, earned_on desc);
create index earnings_engagement_idx on public.earnings (engagement_id) where engagement_id is not null;

-- Rolled-up earnings so income verification does not scan years of raw rows.
-- platform_id null = "all platforms combined" for that period.
create table public.earnings_summaries (
  id                 uuid primary key default gen_random_uuid(),
  worker_id          uuid not null references public.profiles (id) on delete cascade,
  platform_id        uuid references public.platforms (id) on delete cascade,
  period             public.period_type not null default 'month',
  period_start       date not null,
  period_end         date not null,
  gross_earnings     numeric(16,2) not null default 0,
  net_earnings       numeric(16,2) not null default 0,
  deductions         numeric(16,2) not null default 0,
  total_engagements  int not null default 0 check (total_engagements >= 0),
  active_days        int not null default 0 check (active_days >= 0),
  hours_worked       numeric(10,2) not null default 0 check (hours_worked >= 0),
  currency           char(3) not null default 'INR',
  computed_at        timestamptz not null default now(),

  constraint earnings_summaries_period_order check (period_end >= period_start)
);

create unique index earnings_summaries_key
  on public.earnings_summaries (worker_id, coalesce(platform_id, '00000000-0000-0000-0000-000000000000'::uuid), period, period_start);
create index earnings_summaries_worker_idx
  on public.earnings_summaries (worker_id, period, period_start desc);
