-- =====================================================================
-- 15. RLS for the civic tables.
--
--     Civic issues are public by nature - the map is the point - so reads
--     are open. Writes are not: you may file a report and edit your own
--     while it is still open, and nothing else.
-- =====================================================================

alter table public.service_requests  enable row level security;
alter table public.issue_embeddings  enable row level security;
alter table public.clusters          enable row level security;
alter table public.audit_logs        enable row level security;

-- ---------- service_requests --------------------------------------------

create policy service_requests_select_all on public.service_requests
  for select to anon, authenticated using (true);

create policy service_requests_insert_own on public.service_requests
  for insert to authenticated
  with check (reporter_id = auth.uid());

-- A reporter can correct their own report until it has been acted on.
create policy service_requests_update_own on public.service_requests
  for update to authenticated
  using (reporter_id = auth.uid() and status in ('open', 'triaged'))
  with check (reporter_id = auth.uid());

-- Assigned staff and platform admins can move a ticket through its lifecycle.
create policy service_requests_update_staff on public.service_requests
  for update to authenticated
  using (assigned_to = auth.uid() or public.is_platform_admin())
  with check (assigned_to = auth.uid() or public.is_platform_admin());

create policy service_requests_delete_admin on public.service_requests
  for delete to authenticated
  using (public.is_platform_admin());

-- ---------- clusters -----------------------------------------------------

-- Read-only to everyone: clusters are produced by recluster_service_requests(),
-- which runs as SECURITY DEFINER, so no client needs write access.
create policy clusters_select_all on public.clusters
  for select to anon, authenticated using (true);

create policy clusters_write_admin on public.clusters
  for all to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- ---------- issue_embeddings --------------------------------------------

-- Readable so the client can run similarity search; written only by the
-- embedding pipeline holding the service_role key.
create policy issue_embeddings_select on public.issue_embeddings
  for select to authenticated using (true);

create policy issue_embeddings_write_admin on public.issue_embeddings
  for all to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- ---------- audit_logs ---------------------------------------------------

-- Admins read; nobody writes through the API. Rows arrive only via the
-- SECURITY DEFINER trigger, and no UPDATE or DELETE policy exists at all,
-- which is what keeps the trail append-only.
create policy audit_logs_select_admin on public.audit_logs
  for select to authenticated
  using (public.is_platform_admin());
