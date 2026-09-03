#!/usr/bin/env python3
"""
Supabase Database Synchronization & Deployment Utility
Project ID: kblhngnyyaxphzecftet
"""

import argparse
import os
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SQL_FILE = os.path.join(BASE_DIR, "supabase_setup.sql")
PROJECT_REF = "kblhngnyyaxphzecftet"
DEFAULT_HOST = f"db.{PROJECT_REF}.supabase.co"
DEFAULT_PORT = 5432
DEFAULT_USER = "postgres"
DEFAULT_DB = "postgres"


def deploy_via_postgres(password, host=DEFAULT_HOST, port=DEFAULT_PORT, user=DEFAULT_USER, dbname=DEFAULT_DB):
    try:
        import pg8000.native
    except ImportError:
        print("[ERROR] pg8000 is not installed. Run: pip install pg8000")
        sys.exit(1)

    print("=" * 80)
    print("  SUPABASE DIRECT POSTGRESQL DEPLOYMENT")
    print(f"  Project Reference : {PROJECT_REF}")
    print(f"  Target Host       : {host}:{port}")
    print(f"  Database          : {dbname}")
    print(f"  User              : {user}")
    print("=" * 80)

    if not os.path.exists(SQL_FILE):
        print(f"[ERROR] SQL file not found: {SQL_FILE}")
        sys.exit(1)

    with open(SQL_FILE, "r", encoding="utf-8") as f:
        sql_script = f.read()

    print("\n[1/3] Connecting to Supabase PostgreSQL database...")
    try:
        con = pg8000.native.Connection(
            user=user,
            password=password,
            host=host,
            port=port,
            database=dbname,
            ssl_context=True
        )
        print("      -> Connection established successfully.")
    except Exception as e:
        print(f"[FAIL] Could not connect to Supabase: {e}")
        print("\nNote: Make sure your database password is correct, or use the Supabase SQL Editor:")
        print(f"https://supabase.com/dashboard/project/{PROJECT_REF}/sql/new")
        sys.exit(1)

    print("\n[2/3] Executing supabase_setup.sql...")
    try:
        con.run(sql_script)
        print("      -> Schema, tables, triggers, RLS policies, and seed data applied!")
    except Exception as e:
        print(f"[ERROR] Execution failed: {e}")
        con.close()
        sys.exit(1)

    print("\n[3/3] Verifying deployed tables and row counts...")
    tables = [
        "workers", "platforms", "platform_accounts", "work_engagements",
        "earnings_records", "earnings_monthly_summaries", "skills",
        "worker_skills", "platform_ratings", "reputation_scores",
        "organizations", "consent_grants", "reputation_badges", "worker_badges"
    ]
    print("-" * 60)
    print(f"{'Table Name':<35} | {'Row Count'}")
    print("-" * 60)
    for tbl in tables:
        try:
            res = con.run(f"SELECT COUNT(*) FROM {tbl};")
            cnt = res[0][0]
            print(f"{tbl:<35} | {cnt}")
        except Exception as e:
            print(f"{tbl:<35} | Error: {e}")

    con.close()
    print("=" * 80)
    print("  [SUCCESS] All database components and data deployed to Supabase!")
    print("=" * 80)


def test_rest_api(api_key):
    import urllib.request
    import json

    url = f"https://{PROJECT_REF}.supabase.co/rest/v1/workers?select=worker_id,first_name,last_name,did"
    headers = {
        "apikey": api_key,
        "Authorization": f"Bearer {api_key}"
    }

    print(f"[TEST] Querying Supabase PostgREST endpoint: {url}...")
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            print("Status:", resp.status)
            data = json.loads(resp.read().decode("utf-8"))
            print(f"[SUCCESS] Received {len(data)} worker records from Supabase:")
            for w in data:
                print(f"  - {w.get('first_name')} {w.get('last_name')} ({w.get('did')})")
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8")
        print(f"[HTTP Error {e.code}]: {err}")
    except Exception as e:
        print(f"[Error]: {e}")


def main():
    parser = argparse.ArgumentParser(description="Supabase Database Deployment & Sync Utility")
    parser.add_argument("--password", "-p", help="Database password for postgres user")
    parser.add_argument("--host", default=DEFAULT_HOST, help="PostgreSQL host")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="PostgreSQL port")
    parser.add_argument("--test-api", help="Test PostgREST endpoint with provided secret or anon key")

    args = parser.parse_args()

    if args.password:
        deploy_via_postgres(password=args.password, host=args.host, port=args.port)
    elif args.test_api:
        test_rest_api(args.test_api)
    else:
        print("=" * 80)
        print("  SUPABASE SYNC UTILITY - USAGE GUIDE")
        print(f"  Project ID: {PROJECT_REF}")
        print("=" * 80)
        print("\nOption 1: Direct Command-Line Deployment (via Python)")
        print("  Run this command with your Supabase database password:")
        print(f"  python supabase_sync.py --password <YOUR_DB_PASSWORD>")
        print("\nOption 2: 1-Click Copy-Paste in Supabase SQL Editor (Recommended)")
        print(f"  1. Open: https://supabase.com/dashboard/project/{PROJECT_REF}/sql/new")
        print(f"  2. Paste the contents of: supabase_setup.sql")
        print(f"  3. Click 'Run' to create all 20 tables, views, triggers, and seed data.")
        print("=" * 80)


if __name__ == "__main__":
    main()
