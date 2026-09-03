-- =============================================================================
-- Proposed migration: Developer 3 additions
-- Author:   Developer 3
-- Date:     2026-09-03
-- Status:   PROPOSED — requires Developer 1 review and application
--
-- This file proposes schema changes needed for:
--   (a) Portable Worker Public ID (worker_public_id / public_id)
--   (b) Explicit worker_public_profiles table
--
-- Developer 3 does NOT apply this migration directly.
-- Developer 1 must review, adjust RLS policies, and run it.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- (a) Add public_id to the workers table
--
-- Justification:
--   The internal `id` (UUID) is a secret primary key and must never be exposed
--   to external partner systems. A separate `public_id` column:
--     - Is non-guessable (gen_random_uuid())
--     - Can be rotated by the worker without affecting the internal PK,
--       historical records, or foreign keys
--     - Provides a safe external "handle" that resolves to a profile
--       without granting any data access
-- -----------------------------------------------------------------------------
ALTER TABLE workers
  ADD COLUMN IF NOT EXISTS public_id UUID
    DEFAULT gen_random_uuid()
    UNIQUE NOT NULL;

-- Index for fast public-ID lookups
CREATE INDEX IF NOT EXISTS idx_workers_public_id ON workers (public_id);

-- -----------------------------------------------------------------------------
-- (b) Worker public profile settings
--
-- Justification:
--   Workers control which "discoverable" fields are shown at the public
--   lookup endpoint. This separate table keeps public-disclosure preferences
--   out of the core identity record (separation of concerns).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS worker_public_profiles (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  worker_id           UUID NOT NULL UNIQUE REFERENCES workers(id) ON DELETE CASCADE,

  -- Which fields the worker wants discoverable at /api/v1/public/workers/{public_id}
  show_display_name        BOOLEAN NOT NULL DEFAULT true,
  show_verification_badge  BOOLEAN NOT NULL DEFAULT true,
  show_has_reputation      BOOLEAN NOT NULL DEFAULT true,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wpp_worker_id ON worker_public_profiles (worker_id);

-- RLS note for Developer 1:
--   Workers should be able to UPDATE their own worker_public_profiles row.
--   Public-read access (unauthenticated lookup) must be handled at the
--   application layer, not via RLS, since the lookup key is public_id
--   which is on the workers table.

-- -----------------------------------------------------------------------------
-- (c) New audit action types (informational — no schema change needed)
--
-- The following new values will be inserted into access_audit_logs.action:
--   'PUBLIC_PROFILE_VIEWED'   — org/external app looked up worker by public_id
--   'PUBLIC_ID_ROTATED'        — worker regenerated their public_id
--
-- No ALTER TYPE needed if the action column is VARCHAR (it is).
-- -----------------------------------------------------------------------------

COMMENT ON COLUMN workers.public_id IS
  'Externally-shareable, non-guessable worker handle. May be rotated by the worker '
  'without affecting internal worker_id or historical foreign key references. '
  'Owned by Developer 1; added per Developer 3 feature request (public profile lookup).';
