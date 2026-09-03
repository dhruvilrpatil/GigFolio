-- ============================================================================
-- Migration: 001_initial_core_schema
-- Description: Creates initial core tables for workers, platforms, earnings,
--              ratings, and verifiable credentials.
-- ============================================================================

-- >>> UP >>>

PRAGMA foreign_keys = ON;

-- 1. Workers table
CREATE TABLE IF NOT EXISTS workers (
    worker_id TEXT PRIMARY KEY,
    did TEXT UNIQUE NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone_number TEXT UNIQUE NOT NULL,
    date_of_birth TEXT NOT NULL,
    gender TEXT,
    profile_photo_url TEXT,
    bio TEXT,
    primary_city TEXT NOT NULL,
    state_province TEXT NOT NULL,
    country TEXT NOT NULL DEFAULT 'IND',
    postal_code TEXT,
    public_key_pem TEXT NOT NULL,
    kyc_status TEXT NOT NULL DEFAULT 'unverified' CHECK (kyc_status IN ('unverified', 'pending', 'verified', 'rejected', 'expired')),
    biometric_verified INTEGER NOT NULL DEFAULT 0 CHECK (biometric_verified IN (0, 1)),
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    updated_at TEXT NOT NULL DEFAULT (DATETIME('now'))
);

-- 2. Identity documents
CREATE TABLE IF NOT EXISTS identity_documents (
    document_id TEXT PRIMARY KEY,
    worker_id TEXT NOT NULL,
    doc_type TEXT NOT NULL CHECK (doc_type IN ('aadhaar', 'pan_card', 'passport', 'driving_license', 'voter_id', 'national_id', 'ssn')),
    doc_number_masked TEXT NOT NULL,
    doc_hash_sha256 TEXT NOT NULL,
    issuing_country TEXT NOT NULL DEFAULT 'IND',
    issuing_authority TEXT,
    issue_date TEXT,
    expiry_date TEXT,
    verification_status TEXT NOT NULL DEFAULT 'pending' CHECK (verification_status IN ('unverified', 'pending', 'verified', 'rejected', 'expired')),
    verified_at TEXT,
    verified_by TEXT,
    created_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE
);

-- 3. Platforms registry
CREATE TABLE IF NOT EXISTS platforms (
    platform_id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL CHECK (category IN ('rideshare', 'food_delivery', 'parcel_logistics', 'home_services', 'freelance_tech', 'tutoring', 'healthcare_caregiving', 'other')),
    official_api_enabled INTEGER NOT NULL DEFAULT 0 CHECK (official_api_enabled IN (0, 1)),
    trust_score REAL NOT NULL DEFAULT 85.00 CHECK (trust_score BETWEEN 0 AND 100),
    website_url TEXT,
    logo_url TEXT,
    api_endpoint TEXT,
    created_at TEXT NOT NULL DEFAULT (DATETIME('now'))
);

-- 4. Linked platform accounts
CREATE TABLE IF NOT EXISTS platform_accounts (
    account_id TEXT PRIMARY KEY,
    worker_id TEXT NOT NULL,
    platform_id TEXT NOT NULL,
    platform_worker_id TEXT NOT NULL,
    account_status TEXT NOT NULL DEFAULT 'active' CHECK (account_status IN ('active', 'inactive', 'suspended', 'pending_verification', 'deactivated')),
    joined_platform_date TEXT,
    connected_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    last_sync_at TEXT,
    sync_status TEXT DEFAULT 'synced',
    auth_scope TEXT,
    UNIQUE (worker_id, platform_id),
    FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE,
    FOREIGN KEY (platform_id) REFERENCES platforms(platform_id) ON DELETE RESTRICT
);

-- 5. Work engagements (trips, orders, tasks)
CREATE TABLE IF NOT EXISTS work_engagements (
    engagement_id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL,
    worker_id TEXT NOT NULL,
    platform_id TEXT NOT NULL,
    external_engagement_id TEXT,
    engagement_type TEXT NOT NULL,
    started_at TEXT,
    completed_at TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'in_progress', 'cancelled_by_client', 'cancelled_by_worker', 'disputed')),
    duration_minutes INTEGER CHECK (duration_minutes >= 0),
    distance_km REAL CHECK (distance_km >= 0),
    was_disputed INTEGER NOT NULL DEFAULT 0 CHECK (was_disputed IN (0, 1)),
    completion_score REAL DEFAULT 1.00 CHECK (completion_score BETWEEN 0 AND 1.00),
    metadata TEXT,
    created_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    FOREIGN KEY (account_id) REFERENCES platform_accounts(account_id) ON DELETE CASCADE,
    FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE,
    FOREIGN KEY (platform_id) REFERENCES platforms(platform_id) ON DELETE RESTRICT
);

-- 6. Earnings ledger
CREATE TABLE IF NOT EXISTS earnings_records (
    earning_id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL,
    worker_id TEXT NOT NULL,
    platform_id TEXT NOT NULL,
    engagement_id TEXT,
    payout_period_start TEXT NOT NULL,
    payout_period_end TEXT NOT NULL,
    base_amount REAL NOT NULL DEFAULT 0.00 CHECK (base_amount >= 0),
    tips_amount REAL NOT NULL DEFAULT 0.00 CHECK (tips_amount >= 0),
    incentives_bonus REAL NOT NULL DEFAULT 0.00 CHECK (incentives_bonus >= 0),
    platform_deductions REAL NOT NULL DEFAULT 0.00 CHECK (platform_deductions >= 0),
    net_payout REAL NOT NULL CHECK (net_payout >= 0),
    currency TEXT NOT NULL DEFAULT 'INR',
    payout_status TEXT NOT NULL DEFAULT 'paid' CHECK (payout_status IN ('paid', 'pending', 'processing', 'failed', 'disputed')),
    transaction_hash TEXT NOT NULL,
    recorded_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    FOREIGN KEY (account_id) REFERENCES platform_accounts(account_id) ON DELETE CASCADE,
    FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE,
    FOREIGN KEY (platform_id) REFERENCES platforms(platform_id) ON DELETE RESTRICT,
    FOREIGN KEY (engagement_id) REFERENCES work_engagements(engagement_id) ON DELETE SET NULL
);

-- 7. Monthly earnings aggregates
CREATE TABLE IF NOT EXISTS earnings_monthly_summaries (
    summary_id TEXT PRIMARY KEY,
    worker_id TEXT NOT NULL,
    year_period INTEGER NOT NULL CHECK (year_period >= 2020),
    month_period INTEGER NOT NULL CHECK (month_period BETWEEN 1 AND 12),
    total_gross_earnings REAL NOT NULL DEFAULT 0.00,
    total_net_earnings REAL NOT NULL DEFAULT 0.00,
    total_hours_worked REAL NOT NULL DEFAULT 0.00,
    completed_gigs_count INTEGER NOT NULL DEFAULT 0,
    active_platforms_count INTEGER NOT NULL DEFAULT 1,
    income_stability_index REAL DEFAULT 0.850 CHECK (income_stability_index BETWEEN 0 AND 1),
    currency TEXT NOT NULL DEFAULT 'INR',
    created_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    updated_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    UNIQUE (worker_id, year_period, month_period),
    FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE
);

-- 8. Skills catalog & worker mappings
CREATE TABLE IF NOT EXISTS skills (
    skill_id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL,
    description TEXT,
    created_at TEXT NOT NULL DEFAULT (DATETIME('now'))
);

CREATE TABLE IF NOT EXISTS worker_skills (
    worker_skill_id TEXT PRIMARY KEY,
    worker_id TEXT NOT NULL,
    skill_id TEXT NOT NULL,
    proficiency TEXT NOT NULL DEFAULT 'intermediate' CHECK (proficiency IN ('beginner', 'intermediate', 'advanced', 'expert')),
    verified INTEGER NOT NULL DEFAULT 0 CHECK (verified IN (0, 1)),
    years_experience REAL DEFAULT 1.0 CHECK (years_experience >= 0),
    platform_endorsements_count INTEGER NOT NULL DEFAULT 0,
    assessment_score REAL CHECK (assessment_score BETWEEN 0 AND 100),
    verified_at TEXT,
    UNIQUE (worker_id, skill_id),
    FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE,
    FOREIGN KEY (skill_id) REFERENCES skills(skill_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS certifications (
    certification_id TEXT PRIMARY KEY,
    worker_id TEXT NOT NULL,
    title TEXT NOT NULL,
    issuing_body TEXT NOT NULL,
    credential_id_masked TEXT,
    issue_date TEXT NOT NULL,
    expiry_date TEXT,
    verification_url TEXT,
    is_valid INTEGER NOT NULL DEFAULT 1 CHECK (is_valid IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE
);

-- 9. Platform ratings & consolidated reputation
CREATE TABLE IF NOT EXISTS platform_ratings (
    platform_rating_id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL,
    worker_id TEXT NOT NULL,
    platform_id TEXT NOT NULL,
    average_rating REAL NOT NULL CHECK (average_rating BETWEEN 1.00 AND 5.00),
    total_reviews_count INTEGER NOT NULL DEFAULT 0,
    five_star_count INTEGER NOT NULL DEFAULT 0,
    four_star_count INTEGER NOT NULL DEFAULT 0,
    three_star_count INTEGER NOT NULL DEFAULT 0,
    two_star_count INTEGER NOT NULL DEFAULT 0,
    one_star_count INTEGER NOT NULL DEFAULT 0,
    on_time_percentage REAL DEFAULT 98.00 CHECK (on_time_percentage BETWEEN 0 AND 100),
    cancellation_rate REAL DEFAULT 1.50 CHECK (cancellation_rate BETWEEN 0 AND 100),
    last_synced_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    UNIQUE (worker_id, platform_id),
    FOREIGN KEY (account_id) REFERENCES platform_accounts(account_id) ON DELETE CASCADE,
    FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE,
    FOREIGN KEY (platform_id) REFERENCES platforms(platform_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS reputation_scores (
    reputation_id TEXT PRIMARY KEY,
    worker_id TEXT NOT NULL UNIQUE,
    composite_score INTEGER NOT NULL CHECK (composite_score BETWEEN 300 AND 900),
    rating_component INTEGER NOT NULL CHECK (rating_component BETWEEN 0 AND 300),
    volume_tenure_component INTEGER NOT NULL CHECK (volume_tenure_component BETWEEN 0 AND 250),
    reliability_component INTEGER NOT NULL CHECK (reliability_component BETWEEN 0 AND 200),
    diversity_component INTEGER NOT NULL CHECK (diversity_component BETWEEN 0 AND 150),
    tier TEXT NOT NULL DEFAULT 'Silver' CHECK (tier IN ('Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond')),
    total_lifetime_gigs INTEGER NOT NULL DEFAULT 0,
    lifetime_net_earnings REAL NOT NULL DEFAULT 0.00,
    active_platforms_count INTEGER NOT NULL DEFAULT 1,
    last_calculated_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS client_reviews (
    review_id TEXT PRIMARY KEY,
    worker_id TEXT NOT NULL,
    platform_id TEXT NOT NULL,
    engagement_id TEXT,
    rating REAL NOT NULL CHECK (rating BETWEEN 1.0 AND 5.0),
    review_text TEXT,
    reviewer_name_anonymized TEXT,
    sentiment TEXT DEFAULT 'positive',
    reviewed_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE,
    FOREIGN KEY (platform_id) REFERENCES platforms(platform_id) ON DELETE RESTRICT,
    FOREIGN KEY (engagement_id) REFERENCES work_engagements(engagement_id) ON DELETE SET NULL
);

-- 10. Verifiable credentials
CREATE TABLE IF NOT EXISTS verifiable_credentials (
    credential_id TEXT PRIMARY KEY,
    worker_id TEXT NOT NULL,
    credential_type TEXT NOT NULL,
    issuer_did TEXT NOT NULL,
    subject_did TEXT NOT NULL,
    issuance_date TEXT NOT NULL,
    expiration_date TEXT,
    claim_payload TEXT NOT NULL,
    proof_type TEXT NOT NULL DEFAULT 'Ed25519Signature2020',
    signature_value TEXT NOT NULL,
    is_revoked INTEGER NOT NULL DEFAULT 0 CHECK (is_revoked IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE
);

-- 11. Organizations & consent grants
CREATE TABLE IF NOT EXISTS organizations (
    organization_id TEXT PRIMARY KEY,
    legal_name TEXT NOT NULL UNIQUE,
    trade_name TEXT,
    org_type TEXT NOT NULL CHECK (org_type IN ('bank', 'nbfc', 'microfinance', 'insurer', 'gig_platform', 'employer', 'background_verifier', 'government_agency')),
    registration_identifier TEXT NOT NULL UNIQUE,
    contact_email TEXT NOT NULL,
    contact_phone TEXT,
    api_key_hash TEXT NOT NULL,
    is_verified INTEGER NOT NULL DEFAULT 0 CHECK (is_verified IN (0, 1)),
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (DATETIME('now'))
);

CREATE TABLE IF NOT EXISTS consent_grants (
    consent_id TEXT PRIMARY KEY,
    worker_id TEXT NOT NULL,
    organization_id TEXT NOT NULL,
    scope TEXT NOT NULL CHECK (scope IN ('full_profile', 'financial_earnings_only', 'reputation_skills_only', 'identity_verification_only', 'custom')),
    allowed_attributes TEXT NOT NULL,
    purpose TEXT NOT NULL,
    access_token_hash TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked', 'expired')),
    granted_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    expires_at TEXT NOT NULL,
    revoked_at TEXT,
    FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(organization_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS access_audit_logs (
    log_id TEXT PRIMARY KEY,
    consent_id TEXT NOT NULL,
    organization_id TEXT NOT NULL,
    worker_id TEXT NOT NULL,
    request_endpoint TEXT NOT NULL,
    disclosed_attributes TEXT NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    accessed_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    FOREIGN KEY (consent_id) REFERENCES consent_grants(consent_id) ON DELETE RESTRICT,
    FOREIGN KEY (organization_id) REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE
);

-- Core indexes
CREATE INDEX IF NOT EXISTS idx_workers_did ON workers(did);
CREATE INDEX IF NOT EXISTS idx_platform_accounts_worker ON platform_accounts(worker_id);
CREATE INDEX IF NOT EXISTS idx_work_engagements_worker ON work_engagements(worker_id);
CREATE INDEX IF NOT EXISTS idx_earnings_records_worker ON earnings_records(worker_id);
CREATE INDEX IF NOT EXISTS idx_reputation_scores_worker ON reputation_scores(worker_id);
CREATE INDEX IF NOT EXISTS idx_consent_grants_worker ON consent_grants(worker_id);
CREATE INDEX IF NOT EXISTS idx_access_audit_worker ON access_audit_logs(worker_id);

-- >>> DOWN >>>

DROP TABLE IF EXISTS access_audit_logs;
DROP TABLE IF EXISTS consent_grants;
DROP TABLE IF EXISTS organizations;
DROP TABLE IF EXISTS verifiable_credentials;
DROP TABLE IF EXISTS client_reviews;
DROP TABLE IF EXISTS reputation_scores;
DROP TABLE IF EXISTS platform_ratings;
DROP TABLE IF EXISTS certifications;
DROP TABLE IF EXISTS worker_skills;
DROP TABLE IF EXISTS skills;
DROP TABLE IF EXISTS earnings_monthly_summaries;
DROP TABLE IF EXISTS earnings_records;
DROP TABLE IF EXISTS work_engagements;
DROP TABLE IF EXISTS platform_accounts;
DROP TABLE IF EXISTS platforms;
DROP TABLE IF EXISTS identity_documents;
DROP TABLE IF EXISTS workers;
