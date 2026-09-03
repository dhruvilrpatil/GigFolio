-- ============================================================================
-- Migration: 004_webhooks_and_api_keys
-- Description: Adds API key management for organizations and real-time webhook
--              event subscriptions.
-- ============================================================================

-- >>> UP >>>

-- 1. API Keys for external organizations
CREATE TABLE IF NOT EXISTS api_keys (
    key_id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL,
    key_prefix TEXT NOT NULL,
    key_hash TEXT NOT NULL UNIQUE,
    label TEXT NOT NULL,
    allowed_ips TEXT,
    rate_limit_per_minute INTEGER NOT NULL DEFAULT 120 CHECK (rate_limit_per_minute > 0),
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    expires_at TEXT,
    last_used_at TEXT,
    FOREIGN KEY (organization_id) REFERENCES organizations(organization_id) ON DELETE CASCADE
);

-- 2. Webhook subscriptions for real-time external notifications
CREATE TABLE IF NOT EXISTS webhook_subscriptions (
    subscription_id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL,
    endpoint_url TEXT NOT NULL,
    secret_hash TEXT NOT NULL,
    subscribed_events TEXT NOT NULL,                         -- JSON array of event names
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    last_triggered_at TEXT,
    FOREIGN KEY (organization_id) REFERENCES organizations(organization_id) ON DELETE CASCADE
);

-- 3. Webhook delivery events log
CREATE TABLE IF NOT EXISTS webhook_events (
    event_id TEXT PRIMARY KEY,
    subscription_id TEXT NOT NULL,
    event_type TEXT NOT NULL,                               -- 'consent.revoked', 'rating.updated', 'credential.issued'
    worker_id TEXT,
    payload TEXT NOT NULL,                                  -- JSON payload
    delivery_status TEXT NOT NULL DEFAULT 'pending' CHECK (delivery_status IN ('pending', 'delivered', 'failed', 'retrying')),
    response_code INTEGER,
    retry_count INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (DATETIME('now')),
    delivered_at TEXT,
    FOREIGN KEY (subscription_id) REFERENCES webhook_subscriptions(subscription_id) ON DELETE CASCADE,
    FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_api_keys_org ON api_keys(organization_id, is_active);
CREATE INDEX IF NOT EXISTS idx_webhook_sub_org ON webhook_subscriptions(organization_id);
CREATE INDEX IF NOT EXISTS idx_webhook_events_status ON webhook_events(delivery_status);

-- >>> DOWN >>>

DROP TABLE IF EXISTS webhook_events;
DROP TABLE IF EXISTS webhook_subscriptions;
DROP TABLE IF EXISTS api_keys;
