-- ============================================================================
-- Migration: 002_analytics_and_views
-- Description: Adds analytical, financial underwriting, and compliance views.
-- ============================================================================

-- >>> UP >>>

-- 1. Unified 360-degree worker profile view
CREATE VIEW IF NOT EXISTS vw_worker_unified_profile AS
SELECT 
    w.worker_id,
    w.did,
    (w.first_name || ' ' || w.last_name) AS full_name,
    w.primary_city,
    w.country,
    w.kyc_status,
    w.biometric_verified,
    rs.composite_score AS reputation_score,
    rs.tier AS reputation_tier,
    rs.total_lifetime_gigs,
    rs.lifetime_net_earnings,
    rs.active_platforms_count,
    ROUND(AVG(pr.average_rating), 2) AS cross_platform_avg_rating,
    SUM(pr.total_reviews_count) AS total_customer_reviews,
    ROUND(AVG(pr.on_time_percentage), 2) AS avg_on_time_pct,
    ROUND(AVG(pr.cancellation_rate), 2) AS avg_cancellation_pct
FROM workers w
LEFT JOIN reputation_scores rs ON w.worker_id = rs.worker_id
LEFT JOIN platform_ratings pr ON w.worker_id = pr.worker_id
GROUP BY 
    w.worker_id, w.did, w.first_name, w.last_name, w.primary_city, 
    w.country, w.kyc_status, w.biometric_verified, rs.composite_score, 
    rs.tier, rs.total_lifetime_gigs, rs.lifetime_net_earnings, rs.active_platforms_count;

-- 2. Financial health & credit underwriting view (for Banks and NBFCs)
CREATE VIEW IF NOT EXISTS vw_worker_financial_health AS
SELECT 
    w.worker_id,
    w.did,
    (w.first_name || ' ' || w.last_name) AS full_name,
    COUNT(ems.summary_id) AS recorded_months_count,
    ROUND(AVG(ems.total_net_earnings), 2) AS avg_monthly_net_income,
    MIN(ems.total_net_earnings) AS min_monthly_net_income,
    MAX(ems.total_net_earnings) AS max_monthly_net_income,
    ROUND(AVG(ems.income_stability_index), 3) AS avg_stability_index,
    ROUND(AVG(ems.total_hours_worked), 1) AS avg_monthly_hours,
    MAX(ems.active_platforms_count) AS max_simultaneous_platforms
FROM workers w
JOIN earnings_monthly_summaries ems ON w.worker_id = ems.worker_id
GROUP BY w.worker_id, w.did, w.first_name, w.last_name;

-- 3. Cross-platform breakdown view
CREATE VIEW IF NOT EXISTS vw_platform_rating_breakdown AS
SELECT 
    w.worker_id,
    (w.first_name || ' ' || w.last_name) AS worker_name,
    p.name AS platform_name,
    p.category,
    pa.platform_worker_id,
    COALESCE(pr.average_rating, 0.0) AS rating,
    COALESCE(pr.total_reviews_count, 0) AS reviews_count,
    COALESCE(pr.on_time_percentage, 0.0) AS on_time_pct,
    COALESCE(pr.cancellation_rate, 0.0) AS cancellation_rate
FROM platform_accounts pa
JOIN workers w ON pa.worker_id = w.worker_id
JOIN platforms p ON pa.platform_id = p.platform_id
LEFT JOIN platform_ratings pr ON (pa.worker_id = pr.worker_id AND pa.platform_id = pr.platform_id);

-- 4. Active consent compliance view
CREATE VIEW IF NOT EXISTS vw_active_consent_compliance AS
SELECT 
    cg.consent_id,
    cg.worker_id,
    (w.first_name || ' ' || w.last_name) AS worker_name,
    org.organization_id,
    org.legal_name AS organization_name,
    org.org_type,
    cg.scope,
    cg.allowed_attributes,
    cg.status,
    cg.granted_at,
    cg.expires_at,
    CASE 
        WHEN cg.status = 'active' AND cg.expires_at > DATETIME('now') THEN 1 
        ELSE 0 
    END AS is_currently_valid
FROM consent_grants cg
JOIN workers w ON cg.worker_id = w.worker_id
JOIN organizations org ON cg.organization_id = org.organization_id;

-- >>> DOWN >>>

DROP VIEW IF EXISTS vw_active_consent_compliance;
DROP VIEW IF EXISTS vw_platform_rating_breakdown;
DROP VIEW IF EXISTS vw_worker_financial_health;
DROP VIEW IF EXISTS vw_worker_unified_profile;
