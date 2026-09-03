#!/usr/bin/env python3
"""
Digital Identity and Reputation Platform for Gig Workers
Database Setup, Migration Execution, Data Ingestion, and Verification Script
"""

import os
import sqlite3
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "gig_identity.db")
SEED_PATH = os.path.join(BASE_DIR, "seed_data.sql")


def init_database():
    print("=" * 80)
    print("  DIGITAL IDENTITY & REPUTATION PLATFORM FOR GIG WORKERS")
    print("  Automated Database Setup & Migration Lifecycle")
    print("=" * 80)

    # 1. Reset database to test clean migration run
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
        print(f"[OK] Cleaned previous database file: {DB_PATH}")

    # 2. Run migrations using migrate.py logic
    print("\n[1/4] Running schema migrations via migration manager...")
    from migrate import cmd_up
    cmd_up()

    # 3. Apply Seed Data
    print(f"\n[2/4] Ingesting comprehensive seed dataset from: {os.path.basename(SEED_PATH)}...")
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = ON;")
    cursor = conn.cursor()
    with open(SEED_PATH, "r", encoding="utf-8") as f:
        seed_sql = f.read()
    cursor.executescript(seed_sql)
    conn.commit()
    print("      -> Seed data inserted across all 19 entities.")

    # 4. Integrity Check
    print("\n[3/4] Verifying database integrity and relational constraints...")
    from backup_restore import check_integrity
    check_integrity()

    # 5. Verification Queries & Reports
    print("\n[4/4] Executing Platform & Underwriting Verification Reports...")
    print("-" * 80)
    run_verification_queries(conn)

    conn.close()
    print("\n" + "=" * 80)
    print(f"  [SUCCESS] All migrations, entities, and data successfully verified!")
    print("=" * 80)


def print_table(title, headers, rows):
    print(f"\n>>> {title}")
    col_widths = [len(h) for h in headers]
    for row in rows:
        for i, val in enumerate(row):
            col_widths[i] = max(col_widths[i], len(str(val) if val is not None else "NULL"))

    header_line = " | ".join(f"{h:<{col_widths[i]}}" for i, h in enumerate(headers))
    sep_line = "-+-".join("-" * col_widths[i] for i in range(len(headers)))
    print(header_line)
    print(sep_line)
    for row in rows:
        formatted = " | ".join(f"{str(v if v is not None else 'NULL'):<{col_widths[i]}}" for i, v in enumerate(row))
        print(formatted)


def run_verification_queries(conn):
    cursor = conn.cursor()

    # Report 1: Unified Worker Profiles
    cursor.execute("""
        SELECT 
            did,
            full_name,
            primary_city,
            reputation_score,
            reputation_tier,
            total_lifetime_gigs,
            cross_platform_avg_rating,
            active_platforms_count
        FROM vw_worker_unified_profile
        ORDER BY reputation_score DESC;
    """)
    rows = cursor.fetchall()
    headers = ["DID", "Full Name", "City", "Rep Score", "Tier", "Gigs", "Avg Rating", "Platforms"]
    print_table("Report 1: Unified Cross-Platform Worker Profiles", headers, rows)

    # Report 2: Financial Health for Loan Underwriting
    cursor.execute("""
        SELECT 
            full_name,
            recorded_months_count,
            'INR ' || CAST(avg_monthly_net_income AS TEXT) AS avg_monthly_net,
            'INR ' || CAST(min_monthly_net_income AS TEXT) AS min_monthly_net,
            'INR ' || CAST(max_monthly_net_income AS TEXT) AS max_monthly_net,
            avg_stability_index,
            avg_monthly_hours
        FROM vw_worker_financial_health;
    """)
    rows = cursor.fetchall()
    headers = ["Worker", "Months", "Avg Monthly Net", "Min Net", "Max Net", "Stability Index", "Avg Monthly Hrs"]
    print_table("Report 2: Financial Underwriting & Cash Flow Health", headers, rows)

    # Report 3: Portable Reputation Badges
    cursor.execute("""
        SELECT 
            w.first_name || ' ' || w.last_name AS worker_name,
            rb.name AS badge_name,
            rb.category,
            wb.awarded_at
        FROM worker_badges wb
        JOIN workers w ON wb.worker_id = w.worker_id
        JOIN reputation_badges rb ON wb.badge_id = rb.badge_id
        ORDER BY w.first_name, wb.awarded_at;
    """)
    rows = cursor.fetchall()
    headers = ["Worker", "Badge Name", "Category", "Awarded At"]
    print_table("Report 3: Portable Reputation Badges Awarded", headers, rows)

    # Report 4: Dispute Mediation & Reputation Freezing
    cursor.execute("""
        SELECT 
            w.first_name || ' ' || w.last_name AS worker_name,
            p.name AS platform_name,
            d.dispute_type,
            d.status,
            d.reputation_impact_frozen AS is_rep_frozen,
            d.dispute_summary
        FROM disputes d
        JOIN workers w ON d.worker_id = w.worker_id
        JOIN platforms p ON d.platform_id = p.platform_id;
    """)
    rows = cursor.fetchall()
    headers = ["Worker", "Platform", "Dispute Type", "Status", "Rep Frozen?", "Summary"]
    print_table("Report 4: Dispute Mediation & Fair Reputation Protection", headers, rows)

    # Report 5: Registered Webhook Subscriptions
    cursor.execute("""
        SELECT 
            ws.subscription_id,
            org.trade_name,
            ws.endpoint_url,
            ws.subscribed_events,
            ws.is_active
        FROM webhook_subscriptions ws
        JOIN organizations org ON ws.organization_id = org.organization_id;
    """)
    rows = cursor.fetchall()
    headers = ["Subscription ID", "Organization", "Endpoint URL", "Subscribed Events", "Active"]
    print_table("Report 5: Real-Time Webhook Subscriptions", headers, rows)


if __name__ == "__main__":
    init_database()
