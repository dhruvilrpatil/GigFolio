-- =====================================================================
-- Ignite — Digital Identity & Reputation Platform for Gig Workers
-- 01. Extensions and enumerated types
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- Who is using the platform
create type public.user_role as enum (
  'worker',        -- gig worker who owns the identity
  'org_member',    -- read-only seat at a verifying organization
  'org_admin',     -- manages an organization and its seats
  'admin'          -- Ignite platform administrator
);

-- Generic verification lifecycle, reused across documents/skills/credentials
create type public.verification_status as enum (
  'unverified', 'pending', 'verified', 'rejected', 'expired'
);

create type public.kyc_status as enum (
  'not_started', 'pending', 'verified', 'rejected', 'expired'
);

-- Segment of the gig economy a platform operates in
create type public.platform_category as enum (
  'delivery', 'transportation', 'home_services', 'freelancing',
  'care_giving', 'retail', 'logistics', 'education', 'other'
);

-- State of a worker's link to an external platform
create type public.connection_status as enum (
  'pending', 'active', 'syncing', 'error', 'revoked', 'disconnected'
);

-- How the data was pulled from the external platform
create type public.connection_method as enum (
  'oauth', 'api_key', 'credentials', 'document_upload', 'manual_entry'
);

create type public.engagement_status as enum (
  'in_progress', 'completed', 'cancelled', 'disputed', 'rejected'
);

create type public.earning_type as enum (
  'base_pay', 'tip', 'bonus', 'incentive', 'surge',
  'reimbursement', 'adjustment', 'penalty', 'refund'
);

create type public.payout_status as enum (
  'pending', 'processing', 'paid', 'failed', 'reversed'
);

create type public.period_type as enum ('day', 'week', 'month', 'quarter', 'year');

create type public.credential_type as enum (
  'certification', 'license', 'training', 'degree',
  'award', 'background_check', 'insurance'
);

create type public.document_type as enum (
  'national_id', 'passport', 'driving_license', 'address_proof',
  'selfie', 'pan_card', 'voter_id', 'bank_statement', 'tax_document', 'other'
);

create type public.organization_type as enum (
  'bank', 'nbfc', 'employer', 'insurer', 'government',
  'gig_platform', 'landlord', 'other'
);

create type public.org_member_role as enum ('owner', 'admin', 'analyst', 'viewer');

-- Consent lifecycle: a worker granting an organization access to slices of data
create type public.consent_status as enum (
  'pending', 'active', 'revoked', 'expired', 'denied'
);

-- The slices themselves. Every read by an organization is checked against these.
create type public.access_scope as enum (
  'identity', 'contact', 'kyc', 'platform_connections', 'work_history',
  'earnings', 'ratings', 'skills', 'credentials', 'reputation_score', 'documents'
);

create type public.request_status as enum (
  'pending', 'approved', 'denied', 'expired', 'withdrawn'
);

-- What happened to a worker's data, for the audit trail
create type public.audit_action as enum (
  'view', 'export', 'share', 'grant', 'revoke', 'verify',
  'sync', 'report_generate', 'login'
);

create type public.verification_method as enum (
  'platform_api', 'document_ocr', 'manual_review', 'third_party_kyc',
  'otp', 'bank_statement', 'employer_attestation'
);
