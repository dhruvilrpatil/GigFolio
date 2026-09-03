#!/usr/bin/env python3
"""
Gig Worker Digital Identity Platform - Data Access Layer (DAL)
Provides reusable, secure methods for consent enforcement, reputation retrieval,
credential issuance, and audit logging.
"""

import hashlib
import json
import os
import sqlite3
import uuid
from datetime import datetime

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "gig_identity.db")


class GigIdentityDAL:
    def __init__(self, db_path=DB_PATH):
        self.db_path = db_path

    def _get_connection(self):
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON;")
        return conn

    # -------------------------------------------------------------------------
    # 1. Worker Profile & Reputation
    # -------------------------------------------------------------------------
    def get_unified_profile(self, identifier):
        """Retrieve unified profile by worker_id or did"""
        query = """
            SELECT * FROM vw_worker_unified_profile
            WHERE worker_id = ? OR did = ?;
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query, (identifier, identifier))
            row = cursor.fetchone()
            return dict(row) if row else None

    def get_worker_badges(self, worker_id):
        """Retrieve all portable badges earned by a worker"""
        query = """
            SELECT b.name, b.category, b.description, b.icon_url, wb.awarded_at
            FROM worker_badges wb
            JOIN reputation_badges b ON wb.badge_id = b.badge_id
            WHERE wb.worker_id = ? AND wb.revoked_at IS NULL
            ORDER BY wb.awarded_at DESC;
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query, (worker_id,))
            return [dict(r) for r in cursor.fetchall()]

    # -------------------------------------------------------------------------
    # 2. Consent Enforcement & Audit Trail
    # -------------------------------------------------------------------------
    def verify_and_log_access(self, access_token, organization_id, endpoint, requested_attributes, ip_address="127.0.0.1", user_agent="API-Client"):
        """
        Enforces worker consent check:
        1. Checks token hash against consent_grants
        2. Validates expiration and active status
        3. Records access event in immutable access_audit_logs
        """
        token_hash = hashlib.sha256(access_token.encode("utf-8")).hexdigest()

        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT consent_id, worker_id, scope, allowed_attributes, expires_at, status
                FROM consent_grants
                WHERE access_token_hash = ? AND organization_id = ?;
            """, (token_hash, organization_id))
            consent = cursor.fetchone()

            if not consent:
                return {"authorized": False, "reason": "Invalid consent token or organization mismatch"}

            if consent["status"] != "active":
                return {"authorized": False, "reason": f"Consent is {consent['status']}"}

            expires_at = datetime.fromisoformat(consent["expires_at"])
            if expires_at < datetime.now():
                cursor.execute("UPDATE consent_grants SET status = 'expired' WHERE consent_id = ?;", (consent["consent_id"],))
                conn.commit()
                return {"authorized": False, "reason": "Consent grant has expired"}

            # Log disclosure event in audit trail
            log_id = f"log-{uuid.uuid4().hex[:8]}"
            cursor.execute("""
                INSERT INTO access_audit_logs (
                    log_id, consent_id, organization_id, worker_id,
                    request_endpoint, disclosed_attributes, ip_address, user_agent, accessed_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, DATETIME('now'));
            """, (
                log_id,
                consent["consent_id"],
                organization_id,
                consent["worker_id"],
                endpoint,
                json.dumps(requested_attributes),
                ip_address,
                user_agent
            ))
            conn.commit()

            return {
                "authorized": True,
                "worker_id": consent["worker_id"],
                "scope": consent["scope"],
                "audit_log_id": log_id
            }

    # -------------------------------------------------------------------------
    # 3. Financial Profiling (For Underwriting)
    # -------------------------------------------------------------------------
    def get_financial_underwriting_summary(self, worker_id):
        """Retrieve underwriting run-rates and cash flow metrics"""
        query = """
            SELECT * FROM vw_worker_financial_health
            WHERE worker_id = ?;
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query, (worker_id,))
            row = cursor.fetchone()
            return dict(row) if row else None

    # -------------------------------------------------------------------------
    # 4. Dispute Mediation & Reputation Protection
    # -------------------------------------------------------------------------
    def file_dispute(self, worker_id, platform_id, dispute_type, summary, engagement_id=None, claimed_amount=0.0):
        """Files a formal dispute and automatically freezes negative reputation impacts"""
        dispute_id = f"dsp-{uuid.uuid4().hex[:8]}"
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO disputes (
                    dispute_id, worker_id, platform_id, engagement_id,
                    dispute_type, dispute_summary, claimed_amount,
                    status, reputation_impact_frozen, filed_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, 'pending_review', 1, DATETIME('now'));
            """, (dispute_id, worker_id, platform_id, engagement_id, dispute_type, summary, claimed_amount))
            conn.commit()
            return dispute_id

    # -------------------------------------------------------------------------
    # 5. Fraud Detection Alert
    # -------------------------------------------------------------------------
    def record_fraud_alert(self, worker_id, alert_type, severity, confidence_score, details, platform_id=None):
        """Logs an anomaly or potential manipulation event for review"""
        alert_id = f"flt-{uuid.uuid4().hex[:8]}"
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO fraud_risk_alerts (
                    alert_id, worker_id, platform_id, alert_type,
                    severity, confidence_score, details, status, detected_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, 'open', DATETIME('now'));
            """, (alert_id, worker_id, platform_id, alert_type, severity, confidence_score, details))
            conn.commit()
            return alert_id


if __name__ == "__main__":
    dal = GigIdentityDAL()
    print("Testing GigIdentityDAL...")

    # Test 1: Fetch Unified Profile
    profile = dal.get_unified_profile("did:gig:worker:in-blr-78901")
    if profile:
        print(f"[OK] Fetched Profile: {profile['full_name']} | Score: {profile['reputation_score']} | Tier: {profile['reputation_tier']}")

    # Test 2: Fetch Badges
    badges = dal.get_worker_badges(profile["worker_id"])
    print(f"[OK] Badges for {profile['full_name']}: {[b['name'] for b in badges]}")

    # Test 3: Fetch Financials
    fin = dal.get_financial_underwriting_summary(profile["worker_id"])
    if fin:
        print(f"[OK] Financial Run-rate: Avg Monthly Net = INR {fin['avg_monthly_net_income']} | Stability = {fin['avg_stability_index']}")
