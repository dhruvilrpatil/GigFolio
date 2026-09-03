-- =====================================================================
-- 10. Reporting views and private storage buckets
-- =====================================================================

-- The opt-in public profile. Deliberately runs with the view owner's rights
-- (security_invoker off) so it can expose a *narrow, safe column subset*
-- without opening up the underlying profiles row to anonymous readers.
create view public.public_worker_profiles as
select
  wp.public_slug,
  p.id                as worker_id,
  p.display_name,
  p.city,
  p.state,
  p.country,
  p.avatar_url,
  wp.headline,
  wp.primary_category,
  wp.categories,
  wp.years_of_experience,
  wp.available_for_work,
  rs.score            as reputation_score,
  rs.score_band
from public.worker_profiles wp
join public.profiles p on p.id = wp.profile_id
left join public.reputation_scores rs
  on rs.worker_id = p.id and rs.is_current
where wp.is_public and p.is_active;

grant select on public.public_worker_profiles to anon, authenticated;

comment on view public.public_worker_profiles is
  'Anonymous-safe projection of opted-in workers. Never add contact, KYC or earnings columns here.';

-- Consolidated snapshot for the worker dashboard and for consented organizations.
-- security_invoker = on means every underlying RLS policy still applies.
create view public.worker_identity_overview
with (security_invoker = on) as
select
  p.id as worker_id,
  p.full_name,
  p.city,
  p.kyc_status,
  wp.headline,
  wp.primary_category,
  wp.years_of_experience,
  (select count(*) from public.platform_connections c
    where c.worker_id = p.id and c.status = 'active')             as connected_platforms,
  (select count(*) from public.work_engagements w
    where w.worker_id = p.id and w.status = 'completed')          as completed_engagements,
  (select coalesce(sum(e.amount), 0) from public.earnings e
    where e.worker_id = p.id
      and e.earned_on >= current_date - interval '365 days')      as earnings_last_12m,
  (select round(avg(r.rating_value / nullif(r.rating_scale, 0) * 5), 2)
     from public.platform_ratings r
    where r.worker_id = p.id
      and r.as_of >= current_date - interval '90 days')           as avg_rating_5pt,
  (select count(*) from public.credentials cr
    where cr.worker_id = p.id and cr.verification_status = 'verified') as verified_credentials,
  rs.score      as reputation_score,
  rs.score_band
from public.profiles p
join public.worker_profiles wp on wp.profile_id = p.id
left join public.reputation_scores rs on rs.worker_id = p.id and rs.is_current;

grant select on public.worker_identity_overview to authenticated;

-- Monthly income series, the shape a lender actually wants.
create view public.worker_monthly_income
with (security_invoker = on) as
select
  s.worker_id,
  s.period_start                       as month,
  s.gross_earnings,
  s.net_earnings,
  s.total_engagements,
  s.active_days,
  s.currency
from public.earnings_summaries s
where s.period = 'month' and s.platform_id is null;

grant select on public.worker_monthly_income to authenticated;

-- =====================================================================
-- Storage: private buckets, one folder per worker (path = "<worker_id>/...")
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('identity-documents', 'identity-documents', false, 10485760,
   array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
  ('credentials', 'credentials', false, 10485760,
   array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
  ('reports', 'reports', false, 20971520, array['application/pdf']),
  ('avatars', 'avatars', true, 2097152,
   array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- Private buckets: a worker reaches only their own folder.
create policy storage_worker_private_read on storage.objects
  for select to authenticated
  using (
    bucket_id in ('identity-documents', 'credentials', 'reports')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy storage_worker_private_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('identity-documents', 'credentials')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy storage_worker_private_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('identity-documents', 'credentials')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Avatars are world-readable; writes are still folder-scoped.
create policy storage_avatar_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'avatars');

create policy storage_avatar_write on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy storage_avatar_update on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- Organizations fetch consented documents through a signed URL minted by an
-- edge function using the service_role key, after checking public.has_consent().
-- No storage policy grants an organization direct object access by design.
