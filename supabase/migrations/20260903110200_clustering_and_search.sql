-- =====================================================================
-- 14. Backend surface: DBSCAN clustering, spatial search, vector search,
--     hybrid duplicate detection, audit capture, and reporting views.
--
--     Every function pins search_path to public + extensions so PostGIS
--     and pgvector operators resolve regardless of the caller's setting.
-- =====================================================================

-- ---------------------------------------------------------------------
-- ST_ClusterDBSCAN: group nearby reports of the same category
--
-- ST_ClusterDBSCAN is a window function over *geometry*, and its eps is in
-- the SRID's own units - so geography cannot be fed to it directly. We
-- project to EPSG:3857, where distances are inflated by 1/cos(latitude),
-- and scale eps by the same factor so the threshold stays true metres.
-- ---------------------------------------------------------------------
create or replace function public.recluster_service_requests(
  p_eps_meters  numeric  default 150,
  p_min_points  integer  default 3,
  p_category    public.service_request_category default null,
  p_since       timestamptz default (now() - interval '90 days')
)
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_clusters_created integer := 0;
  v_avg_lat          double precision;
  v_eps_projected    double precision;
  rec                record;
  v_cluster_id       uuid;
begin
  -- 1. Detach everything in scope so a re-run is idempotent.
  update public.service_requests sr
     set cluster_id = null
   where sr.reported_at >= p_since
     and (p_category is null or sr.category = p_category)
     and sr.status in ('open', 'triaged', 'assigned', 'in_progress');

  -- 2. Retire clusters that just lost all their members.
  delete from public.clusters c
   where not exists (
     select 1 from public.service_requests s where s.cluster_id = c.id
   );

  -- 3. Mercator distortion correction, guarded against the poles.
  select avg(st_y(sr.location::geometry))
    into v_avg_lat
    from public.service_requests sr
   where sr.reported_at >= p_since
     and (p_category is null or sr.category = p_category)
     and sr.status in ('open', 'triaged', 'assigned', 'in_progress');

  v_eps_projected := p_eps_meters
                     / greatest(cos(radians(coalesce(v_avg_lat, 0))), 0.01);

  -- 4. Run DBSCAN per category and materialise one cluster per label.
  for rec in
    with scoped as (
      select sr.id, sr.category, sr.priority,
             sr.location::geometry as geom,
             sr.reported_at
        from public.service_requests sr
       where sr.reported_at >= p_since
         and (p_category is null or sr.category = p_category)
         and sr.status in ('open', 'triaged', 'assigned', 'in_progress')
    ),
    labeled as (
      select s.*,
             st_clusterdbscan(
               st_transform(s.geom, 3857),
               v_eps_projected,
               p_min_points
             ) over (partition by s.category) as dbscan_label
        from scoped s
    )
    select l.category,
           l.dbscan_label,
           st_centroid(st_collect(l.geom))::geography          as centroid,
           -- Three collinear points hull to a LINESTRING, which the
           -- geography(Polygon) column would reject - so only keep a real one.
           case when count(*) >= 3
                 and st_geometrytype(st_convexhull(st_collect(l.geom))) = 'ST_Polygon'
                then st_convexhull(st_collect(l.geom))::geography
           end                                                  as hull,
           count(*)::integer                                    as member_count,
           min(l.reported_at)                                   as first_reported_at,
           max(l.reported_at)                                   as last_reported_at,
           max(l.priority)                                      as top_priority,
           array_agg(l.id)                                      as member_ids
      from labeled l
     where l.dbscan_label is not null      -- null = noise, left unclustered
     group by l.category, l.dbscan_label
  loop
    insert into public.clusters (
      label, category, centroid, hull, member_count,
      first_reported_at, last_reported_at, priority,
      eps_meters, min_points, computed_at
    )
    values (
      initcap(replace(rec.category::text, '_', ' ')) || ' cluster ('
        || rec.member_count || ' reports)',
      rec.category, rec.centroid, rec.hull, rec.member_count,
      rec.first_reported_at, rec.last_reported_at, rec.top_priority,
      p_eps_meters, p_min_points, now()
    )
    returning id into v_cluster_id;

    update public.service_requests
       set cluster_id = v_cluster_id
     where id = any (rec.member_ids);

    v_clusters_created := v_clusters_created + 1;
  end loop;

  return v_clusters_created;
end;
$$;

comment on function public.recluster_service_requests is
  'Idempotent DBSCAN pass. eps is true metres; Web Mercator distortion is corrected by 1/cos(lat).';

-- ---------------------------------------------------------------------
-- Spatial search - index-backed by service_requests_location_gist
-- ---------------------------------------------------------------------
create or replace function public.nearby_service_requests(
  p_lat            double precision,
  p_lng            double precision,
  p_radius_meters  double precision default 500,
  p_category       public.service_request_category default null,
  p_limit          integer default 50
)
returns table (
  id             uuid,
  ticket_number  text,
  title          text,
  category       public.service_request_category,
  status         public.service_request_status,
  priority       public.service_request_priority,
  distance_m     double precision,
  cluster_id     uuid,
  reported_at    timestamptz
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select sr.id, sr.ticket_number, sr.title, sr.category, sr.status, sr.priority,
         st_distance(sr.location, st_makepoint(p_lng, p_lat)::geography) as distance_m,
         sr.cluster_id, sr.reported_at
    from public.service_requests sr
   -- ST_DWithin first: it is the only sargable predicate here, so the GiST
   -- index does the filtering and ST_Distance only runs on survivors.
   where st_dwithin(sr.location, st_makepoint(p_lng, p_lat)::geography, p_radius_meters)
     and (p_category is null or sr.category = p_category)
   order by sr.location <-> st_makepoint(p_lng, p_lat)::geography
   limit p_limit;
$$;

-- ---------------------------------------------------------------------
-- Vector search - index-backed by issue_embeddings_hnsw
-- ---------------------------------------------------------------------
create or replace function public.find_similar_issues(
  p_embedding       extensions.halfvec(768),
  p_match_count     integer default 10,
  p_min_similarity  double precision default 0.75,
  p_category        public.service_request_category default null,
  p_ef_search       integer default 100
)
returns table (
  service_request_id  uuid,
  ticket_number       text,
  title               text,
  category            public.service_request_category,
  status              public.service_request_status,
  similarity          double precision
)
language plpgsql
stable
security invoker
set search_path = public, extensions
as $$
begin
  -- ef_search trades recall against latency at query time; the default of
  -- 40 is low for a dedup check where a miss means a duplicate ticket.
  perform set_config('hnsw.ef_search', p_ef_search::text, true);

  return query
  select sr.id, sr.ticket_number, sr.title, sr.category, sr.status,
         1 - (ie.embedding operator(extensions.<=>) p_embedding) as similarity
    from public.issue_embeddings ie
    join public.service_requests sr on sr.id = ie.service_request_id
   where (p_category is null or sr.category = p_category)
     and 1 - (ie.embedding operator(extensions.<=>) p_embedding) >= p_min_similarity
   order by ie.embedding operator(extensions.<=>) p_embedding
   limit p_match_count;
end;
$$;

comment on function public.find_similar_issues is
  'Cosine similarity over HNSW. Order by the <=> distance itself - wrapping it in 1-x defeats the index.';

-- ---------------------------------------------------------------------
-- Hybrid duplicate detection: near in space AND near in meaning.
-- This is the query the intake flow runs before opening a new ticket.
-- ---------------------------------------------------------------------
create or replace function public.find_duplicate_candidates(
  p_request_id      uuid,
  p_radius_meters   double precision default 100,
  p_min_similarity  double precision default 0.85,
  p_limit           integer default 5
)
returns table (
  candidate_id    uuid,
  ticket_number   text,
  title           text,
  distance_m      double precision,
  similarity      double precision,
  combined_score  double precision
)
language plpgsql
stable
security invoker
set search_path = public, extensions
as $$
declare
  v_location  extensions.geography(Point, 4326);
  v_embedding extensions.halfvec(768);
  v_category  public.service_request_category;
  v_reported  timestamptz;
begin
  select sr.location, sr.category, sr.reported_at, ie.embedding
    into v_location, v_category, v_reported, v_embedding
    from public.service_requests sr
    left join public.issue_embeddings ie on ie.service_request_id = sr.id
   where sr.id = p_request_id;

  if v_location is null then
    return;   -- unknown request id
  end if;

  perform set_config('hnsw.ef_search', '100', true);

  return query
  select sr.id,
         sr.ticket_number,
         sr.title,
         st_distance(sr.location, v_location) as distance_m,
         case when v_embedding is null or ie.embedding is null then null
              else 1 - (ie.embedding operator(extensions.<=>) v_embedding)
         end as similarity,
         -- Space and meaning weighted 40/60: two reports can be metres apart
         -- and still be different problems, so text carries more weight.
         (0.4 * (1 - least(st_distance(sr.location, v_location) / p_radius_meters, 1))
          + 0.6 * coalesce(
              case when v_embedding is null or ie.embedding is null then 0
                   else 1 - (ie.embedding operator(extensions.<=>) v_embedding)
              end, 0)) as combined_score
    from public.service_requests sr
    left join public.issue_embeddings ie on ie.service_request_id = sr.id
   where sr.id <> p_request_id
     and sr.category = v_category
     and sr.status not in ('closed', 'rejected', 'duplicate')
     and st_dwithin(sr.location, v_location, p_radius_meters)
     and (
       v_embedding is null
       or ie.embedding is null
       or 1 - (ie.embedding operator(extensions.<=>) v_embedding) >= p_min_similarity
     )
   order by combined_score desc
   limit p_limit;
end;
$$;

-- ---------------------------------------------------------------------
-- Cluster hotspots inside a map viewport
-- ---------------------------------------------------------------------
create or replace function public.clusters_in_bbox(
  p_min_lng double precision,
  p_min_lat double precision,
  p_max_lng double precision,
  p_max_lat double precision,
  p_category public.service_request_category default null
)
returns table (
  id            uuid,
  label         text,
  category      public.service_request_category,
  status        public.cluster_status,
  priority      public.service_request_priority,
  lat           double precision,
  lng           double precision,
  member_count  integer,
  last_reported_at timestamptz
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select c.id, c.label, c.category, c.status, c.priority,
         st_y(c.centroid::geometry) as lat,
         st_x(c.centroid::geometry) as lng,
         c.member_count, c.last_reported_at
    from public.clusters c
   where c.status in ('active', 'monitoring')
     and (p_category is null or c.category = p_category)
     and st_intersects(
           c.centroid,
           st_makeenvelope(p_min_lng, p_min_lat, p_max_lng, p_max_lat, 4326)::geography
         )
   order by c.member_count desc;
$$;

-- ---------------------------------------------------------------------
-- Audit capture
-- ---------------------------------------------------------------------
create or replace function public.capture_audit_log()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_old jsonb := case when tg_op = 'INSERT' then null else to_jsonb(old) end;
  v_new jsonb := case when tg_op = 'DELETE' then null else to_jsonb(new) end;
  v_changed text[] := '{}';
begin
  if tg_op = 'UPDATE' then
    select coalesce(array_agg(e.key), '{}'::text[])
      into v_changed
      from jsonb_each(v_new) as e(key, value)
     where v_old -> e.key is distinct from v_new -> e.key;

    -- A touch that changed nothing but updated_at is not worth a row.
    if v_changed = array['updated_at'] or v_changed = '{}' then
      return null;
    end if;
  end if;

  insert into public.audit_logs
    (table_name, record_id, operation, actor_id, old_data, new_data, changed_fields)
  values (
    tg_table_name,
    coalesce((v_new ->> 'id')::uuid, (v_old ->> 'id')::uuid),
    lower(tg_op)::public.audit_operation,
    auth.uid(),
    v_old, v_new, v_changed
  );

  return null;
end;
$$;

create trigger audit_service_requests
  after insert or update or delete on public.service_requests
  for each row execute function public.capture_audit_log();

create trigger audit_clusters
  after insert or update or delete on public.clusters
  for each row execute function public.capture_audit_log();

-- ---------------------------------------------------------------------
-- Views
-- ---------------------------------------------------------------------
create view public.v_service_request_details
with (security_invoker = on) as
select
  sr.id,
  sr.ticket_number,
  sr.title,
  sr.description,
  sr.category,
  sr.subcategory,
  sr.status,
  sr.priority,
  st_y(sr.location::extensions.geometry) as latitude,
  st_x(sr.location::extensions.geometry) as longitude,
  sr.address,
  sr.ward,
  sr.city,
  sr.upvotes,
  sr.reported_at,
  sr.acknowledged_at,
  sr.resolved_at,
  sr.sla_due_at,
  (sr.sla_due_at is not null
   and sr.sla_due_at < now()
   and sr.status not in ('resolved', 'closed', 'rejected', 'duplicate')) as sla_breached,
  sr.cluster_id,
  c.label        as cluster_label,
  c.member_count as cluster_size,
  (ie.service_request_id is not null) as has_embedding,
  sr.reporter_id,
  sr.assigned_to
from public.service_requests sr
left join public.clusters c on c.id = sr.cluster_id
left join public.issue_embeddings ie on ie.service_request_id = sr.id;

create view public.v_cluster_overview
with (security_invoker = on) as
select
  c.id,
  c.label,
  c.category,
  c.status,
  c.priority,
  c.member_count,
  st_y(c.centroid::extensions.geometry) as latitude,
  st_x(c.centroid::extensions.geometry) as longitude,
  c.first_reported_at,
  c.last_reported_at,
  c.eps_meters,
  c.min_points,
  c.computed_at,
  count(sr.id) filter (where sr.status = 'open')     as open_count,
  count(sr.id) filter (where sr.status = 'resolved') as resolved_count,
  max(sr.upvotes)                                    as top_upvotes
from public.clusters c
left join public.service_requests sr on sr.cluster_id = c.id
group by c.id;

create view public.v_open_hotspots
with (security_invoker = on) as
select *
from public.v_cluster_overview
where status in ('active', 'monitoring')
  and member_count >= 3
order by member_count desc, last_reported_at desc;

grant select on public.v_service_request_details to authenticated;
grant select on public.v_cluster_overview        to anon, authenticated;
grant select on public.v_open_hotspots           to anon, authenticated;
