-- ============================================================================
-- DIGITAL IDENTITY & REPUTATION PLATFORM FOR GIG WORKERS
-- Simple & Clean SQLite Schema (8 Core Tables)
-- ============================================================================

PRAGMA foreign_keys = ON;

-- 1. Workers
CREATE TABLE IF NOT EXISTS workers (
    worker_id TEXT PRIMARY KEY,
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT UNIQUE NOT NULL,
    city TEXT NOT NULL,
    profile_photo_url TEXT,
    kyc_verified INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 2. Platforms
CREATE TABLE IF NOT EXISTS platforms (
    platform_id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL,
    logo_url TEXT
);

-- 3. Worker Platforms
CREATE TABLE IF NOT EXISTS worker_platforms (
    id TEXT PRIMARY KEY,
    worker_id TEXT NOT NULL REFERENCES workers(worker_id) ON DELETE CASCADE,
    platform_id TEXT NOT NULL REFERENCES platforms(platform_id) ON DELETE CASCADE,
    platform_worker_id TEXT NOT NULL,
    rating REAL DEFAULT 5.00,
    total_completed_gigs INTEGER DEFAULT 0,
    is_connected INTEGER DEFAULT 1,
    connected_at TEXT DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (worker_id, platform_id)
);

-- 4. Earnings
CREATE TABLE IF NOT EXISTS earnings (
    earning_id TEXT PRIMARY KEY,
    worker_id TEXT NOT NULL REFERENCES workers(worker_id) ON DELETE CASCADE,
    platform_id TEXT NOT NULL REFERENCES platforms(platform_id) ON DELETE CASCADE,
    amount REAL NOT NULL,
    currency TEXT DEFAULT 'INR',
    payout_date TEXT NOT NULL,
    status TEXT DEFAULT 'paid'
);

-- 5. Skills
CREATE TABLE IF NOT EXISTS skills (
    skill_id TEXT PRIMARY KEY,
    worker_id TEXT NOT NULL REFERENCES workers(worker_id) ON DELETE CASCADE,
    skill_name TEXT NOT NULL,
    proficiency TEXT DEFAULT 'Intermediate',
    is_verified INTEGER DEFAULT 0
);

-- 6. Reputation Summary
CREATE TABLE IF NOT EXISTS reputation_summary (
    worker_id TEXT PRIMARY KEY REFERENCES workers(worker_id) ON DELETE CASCADE,
    overall_score INTEGER DEFAULT 750,
    tier TEXT DEFAULT 'Silver',
    average_rating REAL DEFAULT 5.00,
    total_gigs INTEGER DEFAULT 0,
    total_earnings REAL DEFAULT 0.00,
    last_updated TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 7. Organizations
CREATE TABLE IF NOT EXISTS organizations (
    org_id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    org_type TEXT NOT NULL,
    contact_email TEXT NOT NULL
);

-- 8. Profile Access Requests
CREATE TABLE IF NOT EXISTS profile_access_requests (
    request_id TEXT PRIMARY KEY,
    worker_id TEXT NOT NULL REFERENCES workers(worker_id) ON DELETE CASCADE,
    org_id TEXT NOT NULL REFERENCES organizations(org_id) ON DELETE CASCADE,
    purpose TEXT NOT NULL,
    status TEXT DEFAULT 'approved',
    requested_at TEXT DEFAULT CURRENT_TIMESTAMP
);
