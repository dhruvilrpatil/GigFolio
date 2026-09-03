#!/usr/bin/env python3
"""
Production Database Migration Manager for Digital Identity Platform
Supports forward migrations (UP), rollbacks (DOWN), status checks, and resets.
"""

import hashlib
import os
import re
import sqlite3
import sys
import time

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MIGRATIONS_DIR = os.path.join(BASE_DIR, "migrations")
DB_PATH = os.path.join(BASE_DIR, "gig_identity.db")


def get_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = ON;")
    return conn


def ensure_migration_table(conn):
    conn.execute("""
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version INTEGER PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            applied_at TEXT NOT NULL DEFAULT (DATETIME('now')),
            execution_time_ms REAL NOT NULL,
            checksum_sha256 TEXT NOT NULL
        );
    """)
    conn.commit()


def get_migration_files():
    if not os.path.exists(MIGRATIONS_DIR):
        os.makedirs(MIGRATIONS_DIR)
        return []

    pattern = re.compile(r"^(\d+)_(.+)\.sql$")
    files = []
    for fname in os.listdir(MIGRATIONS_DIR):
        match = pattern.match(fname)
        if match:
            version = int(match.group(1))
            name = match.group(2)
            files.append((version, fname, os.path.join(MIGRATIONS_DIR, fname)))
    files.sort(key=lambda x: x[0])
    return files


def parse_migration_file(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    up_marker = "-- >>> UP >>>"
    down_marker = "-- >>> DOWN >>>"

    up_sql = ""
    down_sql = ""

    if up_marker in content and down_marker in content:
        parts = content.split(down_marker)
        up_part = parts[0]
        down_sql = parts[1].strip()
        if up_marker in up_part:
            up_sql = up_part.split(up_marker)[1].strip()
        else:
            up_sql = up_part.strip()
    elif up_marker in content:
        up_sql = content.split(up_marker)[1].strip()
    else:
        up_sql = content.strip()

    sha256 = hashlib.sha256(content.encode("utf-8")).hexdigest()
    return up_sql, down_sql, sha256


def get_applied_migrations(conn):
    cursor = conn.cursor()
    cursor.execute("SELECT version, name, applied_at, checksum_sha256 FROM schema_migrations ORDER BY version ASC;")
    return {row[0]: {"name": row[1], "applied_at": row[2], "checksum": row[3]} for row in cursor.fetchall()}


def cmd_status():
    conn = get_connection()
    ensure_migration_table(conn)
    applied = get_applied_migrations(conn)
    files = get_migration_files()

    print("=" * 80)
    print("  DATABASE MIGRATION STATUS")
    print(f"  Target Database: {os.path.basename(DB_PATH)}")
    print("=" * 80)
    print(f"{'Version':<10} | {'Migration Name':<35} | {'Status':<12} | {'Applied At'}")
    print("-" * 80)

    for version, fname, fpath in files:
        if version in applied:
            status = "APPLIED"
            applied_at = applied[version]["applied_at"]
        else:
            status = "PENDING"
            applied_at = "-"
        base_name = os.path.splitext(fname)[0]
        print(f"{version:<10} | {base_name:<35} | {status:<12} | {applied_at}")

    conn.close()


def cmd_up():
    conn = get_connection()
    ensure_migration_table(conn)
    applied = get_applied_migrations(conn)
    files = get_migration_files()

    pending = [f for f in files if f[0] not in applied]
    if not pending:
        print("[INFO] No pending migrations. Database schema is up to date.")
        conn.close()
        return

    print(f"[START] Applying {len(pending)} pending migration(s)...")
    for version, fname, fpath in pending:
        up_sql, _, checksum = parse_migration_file(fpath)
        if not up_sql:
            print(f"[WARN] No UP script found in {fname}, skipping.")
            continue

        print(f"  -> Migrating [{version:03d}]: {fname}...", end="", flush=True)
        t0 = time.perf_counter()
        cursor = conn.cursor()
        try:
            cursor.executescript(up_sql)
            elapsed_ms = (time.perf_counter() - t0) * 1000
            cursor.execute(
                "INSERT INTO schema_migrations (version, name, applied_at, execution_time_ms, checksum_sha256) VALUES (?, ?, DATETIME('now'), ?, ?);",
                (version, os.path.splitext(fname)[0], elapsed_ms, checksum)
            )
            conn.commit()
            print(f" DONE ({elapsed_ms:.1f}ms)")
        except Exception as e:
            conn.rollback()
            print(f" FAILED!")
            print(f"[ERROR] Migration {fname} failed: {e}")
            conn.close()
            sys.exit(1)

    print("[SUCCESS] All pending migrations successfully applied.")
    conn.close()


def cmd_down():
    conn = get_connection()
    ensure_migration_table(conn)
    applied = get_applied_migrations(conn)
    files = {f[0]: (f[1], f[2]) for f in get_migration_files()}

    if not applied:
        print("[INFO] No applied migrations to roll back.")
        conn.close()
        return

    latest_version = max(applied.keys())
    if latest_version not in files:
        print(f"[ERROR] Migration file for version {latest_version} not found on disk.")
        conn.close()
        sys.exit(1)

    fname, fpath = files[latest_version]
    _, down_sql, _ = parse_migration_file(fpath)

    if not down_sql:
        print(f"[ERROR] Migration {fname} does not contain a -- >>> DOWN >>> rollback block.")
        conn.close()
        sys.exit(1)

    print(f"[ROLLBACK] Reverting migration [{latest_version:03d}]: {fname}...", end="", flush=True)
    t0 = time.perf_counter()
    cursor = conn.cursor()
    try:
        cursor.executescript(down_sql)
        elapsed_ms = (time.perf_counter() - t0) * 1000
        cursor.execute("DELETE FROM schema_migrations WHERE version = ?;", (latest_version,))
        conn.commit()
        print(f" REVERTED ({elapsed_ms:.1f}ms)")
    except Exception as e:
        conn.rollback()
        print(f" FAILED!")
        print(f"[ERROR] Rollback failed: {e}")
        conn.close()
        sys.exit(1)

    conn.close()


def cmd_reset():
    print("[RESET] Reverting all migrations...")
    conn = get_connection()
    ensure_migration_table(conn)
    applied = get_applied_migrations(conn)
    conn.close()

    while applied:
        cmd_down()
        conn = get_connection()
        applied = get_applied_migrations(conn)
        conn.close()

    print("[RESET] Re-applying all migrations from scratch...")
    cmd_up()


def cmd_create(name):
    files = get_migration_files()
    next_ver = 1 if not files else max(f[0] for f in files) + 1
    safe_name = re.sub(r"[^a-zA-Z0-9_]", "_", name.lower())
    filename = f"{next_ver:03d}_{safe_name}.sql"
    filepath = os.path.join(MIGRATIONS_DIR, filename)

    template = f"""-- ============================================================================
-- Migration: {next_ver:03d}_{safe_name}
-- Description: <add description here>
-- ============================================================================

-- >>> UP >>>

-- Add schema changes here:
-- e.g. CREATE TABLE ... or ALTER TABLE ...


-- >>> DOWN >>>

-- Add rollback instructions here:
-- e.g. DROP TABLE ...
"""
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(template)
    print(f"[CREATED] New migration created: migrations/{filename}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python migrate.py [up | down | status | reset | create <name>]")
        sys.exit(0)

    action = sys.argv[1].lower()
    if action == "up":
        cmd_up()
    elif action == "down":
        cmd_down()
    elif action == "status":
        cmd_status()
    elif action == "reset":
        cmd_reset()
    elif action == "create":
        if len(sys.argv) < 3:
            print("Please specify a migration name: python migrate.py create <name>")
            sys.exit(1)
        cmd_create(sys.argv[2])
    else:
        print(f"Unknown action: {action}")
        print("Usage: python migrate.py [up | down | status | reset | create <name>]")


if __name__ == "__main__":
    main()
