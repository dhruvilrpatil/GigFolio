-- =====================================================================
-- 09. Row Level Security
--
-- Model:
--   * A worker owns their rows outright (full CRUD).
--   * An organization sees a worker's row only while public.has_consent()
--     says a live grant covers that data's scope. Revoking the grant cuts
--     off access on the next query - no cached copies, no cleanup job.
--   * Machine-written tables (summaries, scores, logs) have no INSERT
--     policy at all: only the service_role key, which bypasses RLS, writes
--     them. Keep that key on the server.
-- =====================================================================

alter table public.profiles                    enable row level security;
alter table public.worker_profiles             enable row level security;
alter table public.identity_documents          enable row level security;
alter table public.kyc_verifications           enable row level security;
alter table public.platforms                   enable row level security;
alter table public.platform_connections        enable row level security;
alter table public.platform_sync_logs          enable row level security;
alter table public.work_engagements            enable row level security;
alter table public.earnings                    enable row level security;
alter table public.earnings_summaries          enable row level security;
alter table public.platform_ratings            enable row level security;
alter table public.reviews                     enable row level security;
alter table public.skills                      enable row level security;
alter table public.worker_skills               enable row level security;
alter table public.skill_endorsements          enable row level security;
alter table public.credentials                 enable row level security;
alter table public.organizations               enable row level security;
alter table public.organization_members        enable row level security;
alter table public.access_requests             enable row level security;
alter table public.consent_grants              enable row level security;
alter table public.profile_shares              enable row level security;
alter table public.access_logs                 enable row level security;
alter table public.reputation_scores           enable row level security;
alter table public.verification_records        enable row level security;
alter table public.income_verification_reports enable row level security;
alter table public.notifications               enable row level security;

-- ---------- profiles -----------------------------------------------------

create policy profiles_select_self on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.has_consent(id, 'identity') or public.is_platform_admin());

create policy profiles_insert_self on public.profiles
  for insert to authenticated
  with check (id = auth.uid());

create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_platform_admin())
  with check (id = auth.uid() or public.is_platform_admin());

-- ---------- worker_profiles ---------------------------------------------

create policy worker_profiles_select on public.worker_profiles
  for select to authenticated
  using (
    profile_id = auth.uid()
    or public.has_consent(profile_id, 'identity')
    or public.is_platform_admin()
  );

create policy worker_profiles_write_self on public.worker_profiles
  for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- ---------- identity documents and KYC ----------------------------------

create policy identity_documents_select on public.identity_documents
  for select to authenticated
  using (
    worker_id = auth.uid()
    or public.has_consent(worker_id, 'documents')
    or public.is_platform_admin()
  );

create policy identity_documents_write_self on public.identity_documents
  for all to authenticated
  using (worker_id = auth.uid())
  with check (worker_id = auth.uid());

create policy kyc_select on public.kyc_verifications
  for select to authenticated
  using (
    worker_id = auth.uid()
    or public.has_consent(worker_id, 'kyc')
    or public.is_platform_admin()
  );

-- KYC results are written by the provider callback (service_role), never the client.

-- ---------- platform catalogue (public reference data) -------------------

create policy platforms_select_all on public.platforms
  for select to anon, authenticated using (true);

create policy platforms_admin_write on public.platforms
  for all to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());

create policy skills_select_all on public.skills
  for select to anon, authenticated using (true);

create policy skills_admin_write on public.skills
  for all to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());

-- ---------- platform connections ----------------------------------------

create policy platform_connections_select on public.platform_connections
  for select to authenticated
  using (
    worker_id = auth.uid()
    or public.has_consent(worker_id, 'platform_connections')
    or public.is_platform_admin()
  );

create policy platform_connections_write_self on public.platform_connections
  for all to authenticated
  using (worker_id = auth.uid())
  with check (worker_id = auth.uid());

-- Sync logs stay private to the worker: they can leak platform internals.
create policy platform_sync_logs_select_self on public.platform_sync_logs
  for select to authenticated
  using (worker_id = auth.uid() or public.is_platform_admin());

-- ---------- work history -------------------------------------------------

create policy work_engagements_select on public.work_engagements
  for select to authenticated
  using (
    worker_id = auth.uid()
    or public.has_consent(worker_id, 'work_history')
    or public.is_platform_admin()
  );

create policy work_engagements_write_self on public.work_engagements
  for all to authenticated
  using (worker_id = auth.uid())
  with check (worker_id = auth.uid());

-- ---------- earnings -----------------------------------------------------

create policy earnings_select on public.earnings
  for select to authenticated
  using (
    worker_id = auth.uid()
    or public.has_consent(worker_id, 'earnings')
    or public.is_platform_admin()
  );

create policy earnings_write_self on public.earnings
  for all to authenticated
  using (worker_id = auth.uid())
  with check (worker_id = auth.uid());

create policy earnings_summaries_select on public.earnings_summaries
  for select to authenticated
  using (
    worker_id = auth.uid()
    or public.has_consent(worker_id, 'earnings')
    or public.is_platform_admin()
  );

-- ---------- ratings and reviews -----------------------------------------

create policy platform_ratings_select on public.platform_ratings
  for select to authenticated
  using (
    worker_id = auth.uid()
    or public.has_consent(worker_id, 'ratings')
    or public.is_platform_admin()
  );

create policy platform_ratings_write_self on public.platform_ratings
  for all to authenticated
  using (worker_id = auth.uid())
  with check (worker_id = auth.uid());

create policy reviews_select on public.reviews
  for select to authenticated
  using (
    worker_id = auth.uid()
    or public.has_consent(worker_id, 'ratings')
    or public.is_platform_admin()
  );

-- ---------- skills and credentials --------------------------------------

create policy worker_skills_select on public.worker_skills
  for select to authenticated
  using (
    worker_id = auth.uid()
    or public.has_consent(worker_id, 'skills')
    or public.is_platform_admin()
  );

create policy worker_skills_write_self on public.worker_skills
  for all to authenticated
  using (worker_id = auth.uid())
  with check (worker_id = auth.uid());

create policy skill_endorsements_select on public.skill_endorsements
  for select to authenticated
  using (
    exists (
      select 1 from public.worker_skills ws
      where ws.id = skill_endorsements.worker_skill_id
        and (ws.worker_id = auth.uid() or public.has_consent(ws.worker_id, 'skills'))
    )
    or endorser_profile_id = auth.uid()
    or public.is_platform_admin()
  );

-- Anyone signed in may endorse, but only as themselves.
create policy skill_endorsements_insert on public.skill_endorsements
  for insert to authenticated
  with check (endorser_profile_id = auth.uid());

create policy skill_endorsements_delete_own on public.skill_endorsements
  for delete to authenticated
  using (endorser_profile_id = auth.uid());

create policy credentials_select on public.credentials
  for select to authenticated
  using (
    worker_id = auth.uid()
    or public.has_consent(worker_id, 'credentials')
    or public.is_platform_admin()
  );

create policy credentials_write_self on public.credentials
  for all to authenticated
  using (worker_id = auth.uid())
  with check (worker_id = auth.uid());

-- ---------- organizations ------------------------------------------------

-- Workers must be able to see who is asking for their data before consenting.
create policy organizations_select on public.organizations
  for select to authenticated
  using (
    is_active and verification_status = 'verified'
    or public.is_org_member(id)
    or public.is_platform_admin()
  );

create policy organizations_insert on public.organizations
  for insert to authenticated
  with check (created_by = auth.uid());

create policy organizations_update_admin on public.organizations
  for update to authenticated
  using (public.is_org_admin(id) or public.is_platform_admin())
  with check (public.is_org_admin(id) or public.is_platform_admin());

create policy organization_members_select on public.organization_members
  for select to authenticated
  using (profile_id = auth.uid() or public.is_org_member(organization_id) or public.is_platform_admin());

create policy organization_members_manage on public.organization_members
  for all to authenticated
  using (public.is_org_admin(organization_id) or public.is_platform_admin())
  with check (public.is_org_admin(organization_id) or public.is_platform_admin());

-- ---------- access requests and consent ---------------------------------

create policy access_requests_select on public.access_requests
  for select to authenticated
  using (
    worker_id = auth.uid()
    or public.is_org_member(organization_id)
    or public.is_platform_admin()
  );

create policy access_requests_insert_org on public.access_requests
  for insert to authenticated
  with check (public.is_org_member(organization_id) and requested_by = auth.uid());

-- The worker approves or denies; the requesting organization may withdraw.
create policy access_requests_update on public.access_requests
  for update to authenticated
  using (worker_id = auth.uid() or public.is_org_admin(organization_id))
  with check (worker_id = auth.uid() or public.is_org_admin(organization_id));

create policy consent_grants_select on public.consent_grants
  for select to authenticated
  using (
    worker_id = auth.uid()
    or public.is_org_member(organization_id)
    or public.is_platform_admin()
  );

-- Only the worker creates, edits, or revokes a grant. This is the whole point.
create policy consent_grants_insert_worker on public.consent_grants
  for insert to authenticated
  with check (worker_id = auth.uid());

create policy consent_grants_update_worker on public.consent_grants
  for update to authenticated
  using (worker_id = auth.uid())
  with check (worker_id = auth.uid());

create policy consent_grants_delete_worker on public.consent_grants
  for delete to authenticated
  using (worker_id = auth.uid());

-- ---------- share links --------------------------------------------------

create policy profile_shares_own on public.profile_shares
  for all to authenticated
  using (worker_id = auth.uid())
  with check (worker_id = auth.uid());

-- ---------- audit trail (read-only to everyone; written by definer/service) ----

create policy access_logs_select on public.access_logs
  for select to authenticated
  using (
    worker_id = auth.uid()
    or (organization_id is not null and public.is_org_member(organization_id))
    or public.is_platform_admin()
  );

-- ---------- derived trust ------------------------------------------------

create policy reputation_scores_select on public.reputation_scores
  for select to authenticated
  using (
    worker_id = auth.uid()
    or public.has_consent(worker_id, 'reputation_score')
    or public.is_platform_admin()
  );

create policy verification_records_select on public.verification_records
  for select to authenticated
  using (
    worker_id = auth.uid()
    or public.has_consent(worker_id, 'identity')
    or public.is_platform_admin()
  );

create policy income_reports_select on public.income_verification_reports
  for select to authenticated
  using (
    worker_id = auth.uid()
    or (organization_id is not null and public.is_org_member(organization_id))
    or public.is_platform_admin()
  );

-- ---------- notifications ------------------------------------------------

create policy notifications_own on public.notifications
  for select to authenticated using (profile_id = auth.uid());

create policy notifications_update_own on public.notifications
  for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
