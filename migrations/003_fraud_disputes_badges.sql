-- ============================================================================
-- Migration: 003_fraud_disputes_badges
-- Description: Adds fraud & anomaly alerts, dispute mediation records, and 
--              portable reputation badges.
-- ============================================================================

-- >>> UP >>>

-- 1. Fraud and anomaly detection
CREATE TABLE IF NOT EXISTS fraud_risk_alerts (
    alert_id TEXT PRIMARY KEY,
    worker_id TEXT NOT NULL,
    platform_id TEXT,
    alert_type TEXT NOT NULL CHECK (alert_type IN ('review_padding', 'abnormal_velocity', 'spoofed_gps', 'earnings_spike', 'disputed_identity', 'multi_account_conflict')),
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    confidence_score REAL NOT NULL CHECK (confidence_score BETWEEN 0.0 AND 1.0),
    details TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'under_investigation', 'dismissed', 'confirmed')),
    detected_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    resolved_at TEXT,
    resolved_by TEXT,
    FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE,
    FOREIGN KEY (platform_id) REFERENCES platforms(platform_id) ON DELETE SET NULL
);

-- 2. Dispute mediation records (protects worker reputation from unfair retaliatory drops)
CREATE TABLE IF NOT EXISTS disputes (
    dispute_id TEXT PRIMARY KEY,
    worker_id TEXT NOT NULL,
    platform_id TEXT NOT NULL,
    engagement_id TEXT,
    dispute_type TEXT NOT NULL CHECK (dispute_type IN ('unfair_rating', 'payment_withheld', 'account_suspension', 'wrongful_cancellation', 'other')),
    dispute_summary TEXT NOT NULL,
    claimed_amount REAL,
    status TEXT NOT NULL DEFAULT 'pending_review' CHECK (status IN ('pending_review', 'mediation_in_progress', 'resolved_worker_favor', 'resolved_platform_favor', 'withdrawn')),
    reputation_impact_frozen INTEGER NOT NULL DEFAULT 1 CHECK (reputation_impact_frozen IN (0, 1)),
    filed_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    resolved_at TEXT,
    resolution_notes TEXT,
    FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE,
    FOREIGN KEY (platform_id) REFERENCES platforms(platform_id) ON DELETE RESTRICT,
    FOREIGN KEY (engagement_id) REFERENCES work_engagements(engagement_id) ON DELETE SET NULL
);

-- 3. Portable reputation badges catalog
CREATE TABLE IF NOT EXISTS reputation_badges (
    badge_id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL CHECK (category IN ('speed', 'reliability', 'longevity', 'quality', 'safety', 'skill_mastery')),
    description TEXT NOT NULL,
    criteria_json TEXT,
    icon_url TEXT,
    created_at TEXT NOT NULL DEFAULT (DATETIME('now'))
);

-- 4. Worker awarded badges
CREATE TABLE IF NOT EXISTS worker_badges (
    worker_badge_id TEXT PRIMARY KEY,
    worker_id TEXT NOT NULL,
    badge_id TEXT NOT NULL,
    awarded_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    revoked_at TEXT,
    proof_credential_id TEXT,
    UNIQUE (worker_id, badge_id),
    FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE,
    FOREIGN KEY (badge_id) REFERENCES reputation_badges(badge_id) ON DELETE RESTRICT,
    FOREIGN KEY (proof_credential_id) REFERENCES verifiable_credentials(credential_id) ON DELETE SET NULL
);

-- Indexes for fraud, dispute and badge lookups
CREATE INDEX IF NOT EXISTS idx_fraud_worker ON fraud_risk_alerts(worker_id, status);
CREATE INDEX IF NOT EXISTS idx_disputes_worker ON disputes(worker_id, status);
CREATE INDEX IF NOT EXISTS idx_worker_badges_worker ON worker_badges(worker_id);

-- >>> DOWN >>>

DROP TABLE IF EXISTS worker_badges;
DROP TABLE IF EXISTS reputation_badges;
DROP TABLE IF EXISTS disputes;
DROP TABLE IF EXISTS fraud_risk_alerts;
