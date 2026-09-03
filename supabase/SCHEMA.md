# Ignite — database schema

Digital Identity and Reputation Platform for Gig Workers.

The database answers one question at every turn: **who is allowed to see this
slice of this worker's life, and did the worker say yes?** Every organization-
facing read passes through `public.has_consent(worker_id, scope)`.

## Migrations

Applied in filename order by `supabase db push`.

| File | Contents |
|---|---|
| `20260903100000_enums.sql` | All enumerated types |
| `20260903100100_identity_core.sql` | `profiles`, `worker_profiles`, `identity_documents`, `kyc_verifications` |
| `20260903100200_platforms.sql` | `platforms`, `platform_connections`, `platform_sync_logs` |
| `20260903100300_work_and_earnings.sql` | `work_engagements`, `earnings`, `earnings_summaries` |
| `20260903100400_reputation_skills.sql` | `platform_ratings`, `reviews`, `skills`, `worker_skills`, `skill_endorsements`, `credentials` |
| `20260903100500_organizations_consent.sql` | `organizations`, `organization_members`, `access_requests`, `consent_grants`, `profile_shares`, `access_logs` |
| `20260903100600_scores_reports_notifications.sql` | `reputation_scores`, `verification_records`, `income_verification_reports`, `notifications` |
| `20260903100700_functions_triggers.sql` | Signup hook, authorisation helpers, consent expiry, rollups |
| `20260903100800_rls_policies.sql` | Row Level Security on all 26 tables |
| `20260903100900_views_and_storage.sql` | Reporting views, private storage buckets |
| `20260903101000_reference_data.sql` | 18 platforms, 27 skills |

## The four layers

**1. Identity — who the worker is**
`profiles` is 1:1 with `auth.users` and is created automatically by the
`on_auth_user_created` trigger. `worker_profiles` extends it with gig-specific
fields. `identity_documents` stores government IDs as a *masked string plus a
hash* — raw ID numbers are deliberately not storable. `kyc_verifications` keeps
one row per verification attempt.

**2. Ingestion — where the data comes from**
`platforms` is the catalogue (Uber, Swiggy, Upwork, …). `platform_connections`
links a worker to one platform account; the platform's own tokens live in
Supabase Vault and the table holds only a `credential_ref` pointer.
`platform_sync_logs` records each ingestion run, so the worker can see the
provenance of every number on their profile.

**3. Evidence — what the worker has done**
`work_engagements` normalises a ride, a delivery, a home visit and a freelance
milestone into one shape. `earnings` splits money by `earning_type` so a lender
can tell steady base pay from volatile surge bonuses. `earnings_summaries`
holds pre-aggregated periods so income verification never scans years of raw
rows. `platform_ratings`, `reviews`, `worker_skills` and `credentials` carry the
reputation side.

Re-syncing is idempotent: unique indexes on
`(connection_id, external_engagement_id)` and `(connection_id, external_earning_id)`
make a repeated import a no-op rather than a duplicate.

**4. Consent — who gets to look**
An organization files an `access_requests` row naming the scopes and the
purpose. The worker approves, producing a `consent_grants` row. From that moment
`has_consent()` returns true for those scopes, and every RLS policy on the
worker's data starts letting that organization's members read. Revoking flips
`status` to `revoked`, and access stops on the very next query — there is no
cached copy to clean up. `profile_shares` covers the no-account case: a
time-boxed, view-capped token. `access_logs` records every grant, revoke, view
and export.

## Access scopes

`identity`, `contact`, `kyc`, `platform_connections`, `work_history`,
`earnings`, `ratings`, `skills`, `credentials`, `reputation_score`, `documents`.

A grant carries an array of these. Policies check one scope each, so an
organization approved for `earnings` cannot read `documents`.

## Security model

- RLS is enabled on **every** table. The publishable key alone can read nothing
  it should not.
- Workers have full CRUD on their own rows.
- Organizations get **SELECT only**, gated on `has_consent()`.
- Machine-written tables (`earnings_summaries`, `reputation_scores`,
  `access_logs`, `kyc_verifications`, `notifications`) have **no INSERT policy
  at all** — only the `service_role` key, which bypasses RLS, writes them. Keep
  that key on the server, never in the client bundle.
- `access_logs` grants no UPDATE or DELETE to anyone: the audit trail is
  append-only.
- Authorisation helpers are `SECURITY DEFINER` so they can read
  `consent_grants` and `organization_members` from inside a policy without
  recursing into those tables' own policies.
- Storage buckets are private and folder-scoped to `auth.uid()`. Organizations
  never touch objects directly; an edge function checks consent and mints a
  signed URL.

## Helper functions

| Function | Use |
|---|---|
| `has_consent(worker_id, scope)` | The authorisation gate used by every organization-facing policy |
| `is_org_member(org_id)` / `is_org_admin(org_id)` | Seat checks |
| `is_platform_admin()` | Ignite staff |
| `expire_stale_consents()` | Flips lapsed grants to `expired`; schedule nightly with pg_cron |
| `refresh_earnings_summary(worker_id, platform_id, period)` | Rebuilds rollups after a sync |
| `resolve_profile_share(token)` | Validates a share link and bumps its view counter; server-side only |

## Views

- `public_worker_profiles` — anonymous-safe columns for opted-in workers only.
  Intentionally runs with owner rights so it can expose a narrow column subset
  without opening the underlying `profiles` row. **Never add contact, KYC or
  earnings columns to it.**
- `worker_identity_overview` — dashboard snapshot; `security_invoker = on`, so
  RLS still applies.
- `worker_monthly_income` — the monthly series a lender wants.

## Scheduling

Nightly, via pg_cron (enable the extension in the dashboard first):

```sql
select cron.schedule('expire-consents', '0 2 * * *', $$select public.expire_stale_consents()$$);
```

## Deployment

Live on project `udygcptgaewjvowatucq`, region **ap-northeast-1 (Tokyo)**.
All 11 migrations applied 2026-09-03.

Connect for migrations through the **session-mode pooler**:

```
postgresql://postgres.udygcptgaewjvowatucq:<PASSWORD>@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres
```

Two gotchas worth remembering:

- `db.udygcptgaewjvowatucq.supabase.co` does **not resolve** for this project.
  Newer Supabase projects skip the direct host; the pooler is the only route.
- Use port **5432** (session mode). Port 6543 is transaction mode and the
  migration CLI fails against it.

Set `SUPABASE_DB_URL` in `.env.local` (percent-encode the password) and then
`npm run db:dry` / `npm run db:push`.

### Verified after deploy

26 tables, RLS enabled on every one, 49 policies in `public` plus 6 on
`storage.objects`, 19 enums, 11 functions, 3 views, 4 buckets, 18 platforms,
27 skills, signup trigger live, 14 `updated_at` triggers.

Anonymous reads with the publishable key were tested directly: `platforms`
returns rows, while `profiles`, `earnings` and `public_worker_profiles` return
`[]` — RLS is doing its job.

### Not done yet

`npm run db:types` needs Docker (or a `supabase login` access token) and was
skipped. Run it once Docker Desktop is installed to get
`src/lib/database.types.ts`, then pass the generated `Database` type into
`createClient<Database>(...)`.

---

# Part 2 — Civic service requests (geospatial + vector)

A second, independent domain in the same database: citizen-reported civic
issues, clustered by location and de-duplicated by meaning. It shares only
`profiles` (as reporter/assignee) and the `set_updated_at` helper with Part 1.

## Extensions

| Extension | Version | Schema |
|---|---|---|
| PostGIS | 3.3.7 | `extensions` |
| pgvector | 0.8.2 | `extensions` |

Both live in `extensions`, so every type and operator class in these
migrations is **schema-qualified** (`extensions.geography(Point,4326)`,
`extensions.halfvec(768)`, `extensions.halfvec_cosine_ops`,
`operator(extensions.<=>)`). Nothing depends on the caller's `search_path`.

## Tables

| Table | Purpose |
|---|---|
| `service_requests` | One citizen report. `geography(Point,4326)` location, auto `SR-YYYY-NNNNNN` ticket number, self-FK `duplicate_of`, FK to `clusters` |
| `issue_embeddings` | 1:1 with a request (unique FK). `halfvec(768)` embedding |
| `clusters` | A DBSCAN result: centroid, convex hull, member count, and the eps/min_points it was built with |
| `audit_logs` | Append-only change capture for `service_requests` and `clusters` |

## Index strategy

| Kind | Index | Why |
|---|---|---|
| **GiST** | `service_requests_location_gist` | `ST_DWithin` / `<->` KNN on geography |
| **GiST** | `service_requests_location_open_gist` | Partial — live requests only, keeps the hot index small |
| **GiST** | `clusters_centroid_gist` | Viewport queries |
| **HNSW** | `issue_embeddings_hnsw` | `halfvec_cosine_ops`, **m = 16, ef_construction = 64** |
| **B-Tree** | `clusters_category_status_btree`, `clusters_status_recent_btree`, `clusters_member_count_btree`, `clusters_computed_at_btree` | Cluster lookups |
| **BRIN** | `audit_logs_occurred_at_brin` | `pages_per_range = 64`, `autosummarize = on`. Append-only + time-ordered = ideal BRIN correlation |

`halfvec` over `vector` halves index size at negligible recall cost, which is
what keeps the HNSW graph resident in RAM.

## Clustering

`recluster_service_requests(eps_meters, min_points, category, since)`

`ST_ClusterDBSCAN` is a window function over **geometry**, and its eps is in
the SRID's own units — geography cannot be passed to it. The function projects
to EPSG:3857 and divides eps by `cos(latitude)`, because Web Mercator inflates
distance by `1/cos(lat)`. So the caller's eps stays true metres.

It partitions by category (co-located potholes and garbage stay separate
clusters), is idempotent (re-running detaches and rebuilds), and leaves DBSCAN
noise points unclustered rather than forcing them into a group.

## Backend functions

| Function | Use |
|---|---|
| `nearby_service_requests(lat, lng, radius_m, category, limit)` | GiST-backed radius search |
| `find_similar_issues(embedding, count, min_similarity, category, ef_search)` | HNSW cosine search |
| `find_duplicate_candidates(request_id, radius_m, min_similarity, limit)` | Hybrid: near in space **and** in meaning, weighted 40/60 |
| `clusters_in_bbox(min_lng, min_lat, max_lng, max_lat, category)` | Map viewport |
| `recluster_service_requests(...)` | DBSCAN pass |

Views: `v_service_request_details` (lat/lng split out, SLA breach computed),
`v_cluster_overview`, `v_open_hotspots`.

## Query optimisation notes

- **Order by the raw distance operator.** `order by embedding <=> $1` uses the
  HNSW index; `order by 1 - (embedding <=> $1)` does not. The similarity value
  is computed in the select list, never in the ordering.
- **`ST_DWithin`, not `ST_Distance < x`.** Only the former is sargable, so the
  GiST index filters and `ST_Distance` runs on survivors.
- **`ef_search` is raised to 100** (default 40) inside the search functions via
  `set_config(..., true)` — transaction-local, so it never leaks. For a dedup
  check a missed neighbour means a duplicate ticket, which costs more than the
  extra latency.
- Partial indexes exclude closed/resolved rows from the hot paths.

## Verified live

Seeded 15 requests across two Mumbai locations plus noise, then:

- DBSCAN produced **3 clusters** (5 potholes, 4 potholes 8 km away, 4 garbage
  co-located with the first) and left the **2 noise points unclustered**.
- `EXPLAIN` confirmed all four index types are used: `Index Scan using
  service_requests_location_gist`, `Index Scan using issue_embeddings_hnsw`,
  `Bitmap Index Scan on audit_logs_occurred_at_brin`, `Index Scan using
  clusters_status_recent_btree`.
- Audit capture wrote 15 inserts + 13 updates, with `changed_fields` correctly
  narrowed to `["cluster_id"]` and the updated_at-only pass suppressed.

Test data was removed afterwards; all four tables are empty and the ticket
sequence is reset.
