-- ============================================================================
-- DIGITAL IDENTITY & REPUTATION PLATFORM FOR GIG WORKERS
-- Simple & Clean PostgreSQL Schema (8 Core Tables)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Workers: Master identity profile
CREATE TABLE IF NOT EXISTS workers (
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

-- 2. Platforms: Gig companies (Uber, Swiggy, Zomato, Urban Company, Upwork, etc.)
CREATE TABLE IF NOT EXISTS platforms (
    platform_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL,
    logo_url TEXT
);

-- 3. Worker Platforms: Connects workers to multiple gig apps with ratings
CREATE TABLE IF NOT EXISTS worker_platforms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL REFERENCES workers(worker_id) ON DELETE CASCADE,
    platform_id UUID NOT NULL REFERENCES platforms(platform_id) ON DELETE CASCADE,
    platform_worker_id TEXT NOT NULL,
    rating NUMERIC(3, 2) DEFAULT 5.00,
    total_completed_gigs INTEGER DEFAULT 0,
    is_connected BOOLEAN DEFAULT TRUE,
    connected_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_worker_platform UNIQUE (worker_id, platform_id)
);

-- 4. Earnings: Income history for loans & credit underwriting
CREATE TABLE IF NOT EXISTS earnings (
    earning_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL REFERENCES workers(worker_id) ON DELETE CASCADE,
    platform_id UUID NOT NULL REFERENCES platforms(platform_id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'INR',
    payout_date DATE NOT NULL,
    status TEXT DEFAULT 'paid'
);

-- 5. Skills: Verified skills & certifications
CREATE TABLE IF NOT EXISTS skills (
    skill_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL REFERENCES workers(worker_id) ON DELETE CASCADE,
    skill_name TEXT NOT NULL,
    proficiency TEXT DEFAULT 'Intermediate',
    is_verified BOOLEAN DEFAULT FALSE
);

-- 6. Reputation Summary: Unified score and tier across platforms
CREATE TABLE IF NOT EXISTS reputation_summary (
    worker_id UUID PRIMARY KEY REFERENCES workers(worker_id) ON DELETE CASCADE,
    overall_score INTEGER DEFAULT 750 CHECK (overall_score BETWEEN 300 AND 900),
    tier TEXT DEFAULT 'Silver',
    average_rating NUMERIC(3, 2) DEFAULT 5.00,
    total_gigs INTEGER DEFAULT 0,
    total_earnings NUMERIC(12, 2) DEFAULT 0.00,
    last_updated TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Organizations: Banks, NBFCs, insurers, employers
CREATE TABLE IF NOT EXISTS organizations (
    org_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    org_type TEXT NOT NULL,
    contact_email TEXT NOT NULL
);

-- 8. Profile Access Requests: Worker data sharing & consent
CREATE TABLE IF NOT EXISTS profile_access_requests (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL REFERENCES workers(worker_id) ON DELETE CASCADE,
    org_id UUID NOT NULL REFERENCES organizations(org_id) ON DELETE CASCADE,
    purpose TEXT NOT NULL,
    status TEXT DEFAULT 'approved',
    requested_at TIMESTAMPTZ DEFAULT NOW()
);
