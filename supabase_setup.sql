-- ============================================================================
-- DIGITAL IDENTITY & REPUTATION PLATFORM FOR GIG WORKERS
-- Simple & Clean Supabase Schema (8 Core Tables)
-- Project ID: kblhngnyyaxphzecftet
-- ============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ----------------------------------------------------------------------------
-- 1. CLEANUP EXISTING TABLES & VIEWS
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_worker_unified_profile CASCADE;
DROP VIEW IF EXISTS vw_worker_financial_health CASCADE;

DROP TABLE IF EXISTS profile_access_requests CASCADE;
DROP TABLE IF EXISTS organizations CASCADE;
DROP TABLE IF EXISTS reputation_summary CASCADE;
DROP TABLE IF EXISTS skills CASCADE;
DROP TABLE IF EXISTS earnings CASCADE;
DROP TABLE IF EXISTS worker_platforms CASCADE;
DROP TABLE IF EXISTS platforms CASCADE;
DROP TABLE IF EXISTS workers CASCADE;

-- Legacy tables cleanup (in case older versions exist)
DROP TABLE IF EXISTS webhook_events CASCADE;
DROP TABLE IF EXISTS webhook_subscriptions CASCADE;
DROP TABLE IF EXISTS api_keys CASCADE;
DROP TABLE IF EXISTS fraud_risk_alerts CASCADE;
DROP TABLE IF EXISTS verifiable_credentials CASCADE;
DROP TABLE IF EXISTS disputes CASCADE;
DROP TABLE IF EXISTS worker_badges CASCADE;
DROP TABLE IF EXISTS reputation_badges CASCADE;
DROP TABLE IF EXISTS access_audit_logs CASCADE;
DROP TABLE IF EXISTS consent_grants CASCADE;
DROP TABLE IF EXISTS client_reviews CASCADE;
DROP TABLE IF EXISTS reputation_scores CASCADE;
DROP TABLE IF EXISTS platform_ratings CASCADE;
DROP TABLE IF EXISTS certifications CASCADE;
DROP TABLE IF EXISTS worker_skills CASCADE;
DROP TABLE IF EXISTS earnings_monthly_summaries CASCADE;
DROP TABLE IF EXISTS earnings_records CASCADE;
DROP TABLE IF EXISTS work_engagements CASCADE;
DROP TABLE IF EXISTS platform_accounts CASCADE;
DROP TABLE IF EXISTS identity_documents CASCADE;

-- ----------------------------------------------------------------------------
-- 2. CORE DATABASE TABLES
-- ----------------------------------------------------------------------------

-- 1. Workers: Master identity profile
CREATE TABLE workers (
    worker_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT UNIQUE NOT NULL,
    city TEXT NOT NULL,
    profile_photo_url TEXT,
    kyc_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Platforms: Gig companies (Uber, Swiggy, Zomato, Urban Company, etc.)
CREATE TABLE platforms (
    platform_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL, -- e.g. Rideshare, Food Delivery, Home Services, Tech
    logo_url TEXT
);

-- 3. Worker Platforms: Connects workers to multiple gig apps with their ratings
CREATE TABLE worker_platforms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL REFERENCES workers(worker_id) ON DELETE CASCADE,
    platform_id UUID NOT NULL REFERENCES platforms(platform_id) ON DELETE CASCADE,
    platform_worker_id TEXT NOT NULL, -- Worker's ID inside that platform
    rating NUMERIC(3, 2) DEFAULT 5.00,
    total_completed_gigs INTEGER DEFAULT 0,
    is_connected BOOLEAN DEFAULT TRUE,
    connected_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_worker_platform UNIQUE (worker_id, platform_id)
);

-- 4. Earnings: Consolidated income records for credit evaluation & loans
CREATE TABLE earnings (
    earning_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL REFERENCES workers(worker_id) ON DELETE CASCADE,
    platform_id UUID NOT NULL REFERENCES platforms(platform_id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'INR',
    payout_date DATE NOT NULL,
    status TEXT DEFAULT 'paid' -- 'paid', 'pending'
);

-- 5. Skills: Verified professional skills & credentials
CREATE TABLE skills (
    skill_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL REFERENCES workers(worker_id) ON DELETE CASCADE,
    skill_name TEXT NOT NULL,
    proficiency TEXT DEFAULT 'Intermediate', -- 'Beginner', 'Intermediate', 'Expert'
    is_verified BOOLEAN DEFAULT FALSE
);

-- 6. Reputation Summary: Unified score and tier across all platforms
CREATE TABLE reputation_summary (
    worker_id UUID PRIMARY KEY REFERENCES workers(worker_id) ON DELETE CASCADE,
    overall_score INTEGER DEFAULT 750 CHECK (overall_score BETWEEN 300 AND 900),
    tier TEXT DEFAULT 'Silver', -- 'Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond'
    average_rating NUMERIC(3, 2) DEFAULT 5.00,
    total_gigs INTEGER DEFAULT 0,
    total_earnings NUMERIC(12, 2) DEFAULT 0.00,
    last_updated TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Organizations: Banks, lenders, background checkers & employers
CREATE TABLE organizations (
    org_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    org_type TEXT NOT NULL, -- 'Bank', 'NBFC', 'Insurer', 'Employer'
    contact_email TEXT NOT NULL
);

-- 8. Profile Access Requests: Worker data sharing & consent management
CREATE TABLE profile_access_requests (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL REFERENCES workers(worker_id) ON DELETE CASCADE,
    org_id UUID NOT NULL REFERENCES organizations(org_id) ON DELETE CASCADE,
    purpose TEXT NOT NULL, -- e.g. 'Vehicle Loan Pre-Approval'
    status TEXT DEFAULT 'approved', -- 'pending', 'approved', 'rejected'
    requested_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 3. UNIFIED PROFILE VIEW
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_worker_unified_profile AS
SELECT 
    w.worker_id,
    w.full_name,
    w.email,
    w.phone,
    w.city,
    w.kyc_verified,
    rs.overall_score AS reputation_score,
    rs.tier AS reputation_tier,
    rs.average_rating,
    rs.total_gigs,
    rs.total_earnings,
    COUNT(DISTINCT wp.platform_id) AS total_connected_platforms
FROM workers w
LEFT JOIN reputation_summary rs ON w.worker_id = rs.worker_id
LEFT JOIN worker_platforms wp ON w.worker_id = wp.worker_id
GROUP BY 
    w.worker_id, w.full_name, w.email, w.phone, w.city, w.kyc_verified,
    rs.overall_score, rs.tier, rs.average_rating, rs.total_gigs, rs.total_earnings;

-- ----------------------------------------------------------------------------
-- 4. SUPABASE PERMISSIONS & ROW LEVEL SECURITY (RLS)
-- ----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

-- Enable Row Level Security on all 8 tables
ALTER TABLE workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE platforms ENABLE ROW LEVEL SECURITY;
ALTER TABLE worker_platforms ENABLE ROW LEVEL SECURITY;
ALTER TABLE earnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE reputation_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE profile_access_requests ENABLE ROW LEVEL SECURITY;

-- Permissive read policies for standard client access
DROP POLICY IF EXISTS "Public read workers" ON workers;
CREATE POLICY "Public read workers" ON workers FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public read platforms" ON platforms;
CREATE POLICY "Public read platforms" ON platforms FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public read worker_platforms" ON worker_platforms;
CREATE POLICY "Public read worker_platforms" ON worker_platforms FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public read earnings" ON earnings;
CREATE POLICY "Public read earnings" ON earnings FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public read skills" ON skills;
CREATE POLICY "Public read skills" ON skills FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public read reputation_summary" ON reputation_summary;
CREATE POLICY "Public read reputation_summary" ON reputation_summary FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public read organizations" ON organizations;
CREATE POLICY "Public read organizations" ON organizations FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public read profile_access_requests" ON profile_access_requests;
CREATE POLICY "Public read profile_access_requests" ON profile_access_requests FOR SELECT USING (true);
