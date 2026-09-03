-- =====================================================================
-- 08. Functions and triggers
--     Authorisation helpers are SECURITY DEFINER on purpose: they read
--     consent/membership tables from inside RLS policies without
--     re-triggering those tables' own policies (which would recurse).
-- =====================================================================

-- ---------- housekeeping -------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles', 'worker_profiles', 'identity_documents', 'kyc_verifications',
    'platforms', 'platform_connections', 'work_engagements', 'earnings',
    'platform_ratings', 'worker_skills', 'credentials', 'organizations',
    'access_requests', 'consent_grants'
  ]
  loop
    execute format(
      'create trigger set_updated_at before update on public.%I
         for each row execute function public.set_updated_at()', t);
  end loop;
end;
$$;

-- ---------- signup -------------------------------------------------------

-- Every new auth user gets a profile; workers additionally get a worker_profile.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role public.user_role;
begin
  v_role := case
    when new.raw_user_meta_data ->> 'role' in ('worker', 'org_member', 'org_admin')
      then (new.raw_user_meta_data ->> 'role')::public.user_role
    else 'worker'::public.user_role
  end;

  insert into public.profiles (id, email, full_name, phone, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.raw_user_meta_data ->> 'phone',
    v_role
  )
  on conflict (id) do nothing;

  if v_role = 'worker' then
    insert into public.worker_profiles (profile_id)
    values (new.id)
    on conflict (profile_id) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- authorisation helpers ---------------------------------------

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.is_org_member(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.organization_members m
    where m.organization_id = p_organization_id
      and m.profile_id = auth.uid()
      and m.is_active
  );
$$;

create or replace function public.is_org_admin(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.organization_members m
    where m.organization_id = p_organization_id
      and m.profile_id = auth.uid()
      and m.is_active
      and m.role in ('owner', 'admin')
  );
$$;

-- The single gate every organization-facing policy goes through:
-- "does an organization I belong to hold a live grant from this worker for this scope?"
create or replace function public.has_consent(p_worker_id uuid, p_scope public.access_scope)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.consent_grants g
    join public.organization_members m
      on m.organization_id = g.organization_id
    where g.worker_id = p_worker_id
      and m.profile_id = auth.uid()
      and m.is_active
      and g.status = 'active'
      and (g.expires_at is null or g.expires_at > now())
      and p_scope = any (g.scopes)
  );
$$;

comment on function public.has_consent(uuid, public.access_scope) is
  'True when the caller sits at an organization holding an active, unexpired grant covering p_scope.';

-- ---------- consent lifecycle -------------------------------------------

-- Flip grants to 'expired' once their window closes. Schedule via pg_cron.
create or replace function public.expire_stale_consents()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  update public.consent_grants
     set status = 'expired', updated_at = now()
   where status = 'active'
     and expires_at is not null
     and expires_at <= now();
  get diagnostics v_count = row_count;

  update public.access_requests
     set status = 'expired', updated_at = now()
   where status = 'pending'
     and expires_at <= now();

  return v_count;
end;
$$;

-- Consent changes are themselves auditable events.
create or replace function public.log_consent_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.access_logs
      (worker_id, actor_profile_id, organization_id, consent_grant_id, action, scopes_accessed)
    values
      (new.worker_id, auth.uid(), new.organization_id, new.id, 'grant', new.scopes);
  elsif tg_op = 'UPDATE' and new.status = 'revoked' and old.status <> 'revoked' then
    insert into public.access_logs
      (worker_id, actor_profile_id, organization_id, consent_grant_id, action, scopes_accessed)
    values
      (new.worker_id, auth.uid(), new.organization_id, new.id, 'revoke', new.scopes);
  end if;
  return new;
end;
$$;

create trigger log_consent_grant_change
  after insert or update on public.consent_grants
  for each row execute function public.log_consent_change();

-- ---------- denormalised counters ---------------------------------------

create or replace function public.sync_endorsement_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_worker_skill uuid := coalesce(new.worker_skill_id, old.worker_skill_id);
begin
  update public.worker_skills ws
     set endorsement_count = (
           select count(*) from public.skill_endorsements e
            where e.worker_skill_id = v_worker_skill
         )
   where ws.id = v_worker_skill;
  return null;
end;
$$;

create trigger sync_endorsement_count
  after insert or delete on public.skill_endorsements
  for each row execute function public.sync_endorsement_count();

-- ---------- earnings rollup ---------------------------------------------

-- Recompute monthly summaries for one worker. Call after a sync, or nightly.
-- Passing p_platform_id null recomputes the combined all-platforms series.
create or replace function public.refresh_earnings_summary(
  p_worker_id uuid,
  p_platform_id uuid default null,
  p_period public.period_type default 'month'
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
  v_unit text := case p_period
                   when 'day' then 'day'
                   when 'week' then 'week'
                   when 'month' then 'month'
                   when 'quarter' then 'quarter'
                   else 'year'
                 end;
begin
  insert into public.earnings_summaries as s (
    worker_id, platform_id, period, period_start, period_end,
    gross_earnings, net_earnings, deductions,
    total_engagements, active_days, currency, computed_at
  )
  select
    e.worker_id,
    p_platform_id,
    p_period,
    (date_trunc(v_unit, e.earned_on::timestamp))::date,
    (date_trunc(v_unit, e.earned_on::timestamp)
       + format('1 %s', v_unit)::interval - interval '1 day')::date,
    coalesce(sum(e.amount) filter (where e.amount > 0), 0),
    coalesce(sum(e.amount), 0),
    abs(coalesce(sum(e.amount) filter (where e.amount < 0), 0)),
    count(distinct e.engagement_id),
    count(distinct e.earned_on),
    max(e.currency),
    now()
  from public.earnings e
  where e.worker_id = p_worker_id
    and (p_platform_id is null or e.platform_id = p_platform_id)
  -- Group on the bare date_trunc, not its ::date cast: the period_end
  -- expression above contains date_trunc as a subexpression, and Postgres
  -- only accepts select-list expressions built out of the grouped one.
  group by e.worker_id, date_trunc(v_unit, e.earned_on::timestamp)
  on conflict (worker_id, coalesce(platform_id, '00000000-0000-0000-0000-000000000000'::uuid),
               period, period_start)
  do update set
    gross_earnings    = excluded.gross_earnings,
    net_earnings      = excluded.net_earnings,
    deductions        = excluded.deductions,
    total_engagements = excluded.total_engagements,
    active_days       = excluded.active_days,
    currency          = excluded.currency,
    computed_at       = now();

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ---------- share links --------------------------------------------------

-- Resolve a share token to its worker, enforcing expiry and view caps.
-- Returns null when the link is dead. Intended to be called from an edge function.
create or replace function public.resolve_profile_share(p_token text)
returns table (worker_id uuid, scopes public.access_scope[], share_id uuid)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with bumped as (
    update public.profile_shares s
       set view_count = s.view_count + 1
     where s.share_token = p_token
       and s.is_active
       and (s.expires_at is null or s.expires_at > now())
       and (s.max_views is null or s.view_count < s.max_views)
    returning s.worker_id, s.scopes, s.id
  )
  select b.worker_id, b.scopes, b.id from bumped b;
end;
$$;

revoke execute on function public.resolve_profile_share(text) from public, anon, authenticated;
