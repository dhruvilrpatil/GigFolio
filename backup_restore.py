#!/usr/bin/env python3
"""
Gig Worker Digital Identity Platform - Database Backup & Integrity Utility
Performs online atomic backups, database restores, and integrity verification.
"""

import hashlib
import os
import shutil
import sqlite3
import sys
from datetime import datetime

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "gig_identity.db")
BACKUP_DIR = os.path.join(BASE_DIR, "backups")


def ensure_backup_dir():
    if not os.path.exists(BACKUP_DIR):
        os.makedirs(BACKUP_DIR)


def compute_file_sha256(filepath):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()


def backup():
    if not os.path.exists(DB_PATH):
        print(f"[ERROR] Database file not found: {DB_PATH}")
        sys.exit(1)

    ensure_backup_dir()
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_filename = f"gig_identity_backup_{timestamp}.db"
    backup_path = os.path.join(BACKUP_DIR, backup_filename)

    print("=" * 80)
    print("  CREATING DATABASE BACKUP")
    print("=" * 80)
    print(f"Source Database : {DB_PATH}")
    print(f"Backup Target   : {backup_path}")

    # Use SQLite online backup API for safe, non-blocking backup
    src_conn = sqlite3.connect(DB_PATH)
    dst_conn = sqlite3.connect(backup_path)
    with dst_conn:
        src_conn.backup(dst_conn, pages=100)
    dst_conn.close()
    src_conn.close()

    sha256 = compute_file_sha256(backup_path)
    size_kb = os.path.getsize(backup_path) / 1024

    print(f"[OK] Backup created successfully!")
    print(f"     Size     : {size_kb:.2f} KB")
    print(f"     SHA-256  : {sha256}")


def check_integrity():
    if not os.path.exists(DB_PATH):
        print(f"[ERROR] Database file not found: {DB_PATH}")
        sys.exit(1)

    print("=" * 80)
    print("  DATABASE INTEGRITY VERIFICATION")
    print("=" * 80)

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # 1. PRAGMA integrity_check
    cursor.execute("PRAGMA integrity_check;")
    integrity = cursor.fetchall()
    print("1. Low-level Integrity Check:")
    for row in integrity:
        print(f"   -> {row[0]}")

    # 2. PRAGMA foreign_key_check
    cursor.execute("PRAGMA foreign_key_check;")
    fk_errors = cursor.fetchall()
    print("2. Foreign Key Constraint Check:")
    if not fk_errors:
        print("   -> [OK] All foreign key relationships are completely valid.")
    else:
        print(f"   -> [FAIL] Detected {len(fk_errors)} foreign key violations:")
        for err in fk_errors:
            print(f"      Table: {err[0]}, RowId: {err[1]}, Target: {err[2]}, FkId: {err[3]}")

    conn.close()


def restore(backup_filename):
    backup_path = os.path.join(BACKUP_DIR, backup_filename)
    if not os.path.exists(backup_path):
        # Also check if user passed full path
        if os.path.exists(backup_filename):
            backup_path = backup_filename
        else:
            print(f"[ERROR] Backup file not found: {backup_path}")
            sys.exit(1)

    print("=" * 80)
    print("  RESTORING DATABASE FROM BACKUP")
    print("=" * 80)
    print(f"Backup Source : {backup_path}")
    print(f"Target DB     : {DB_PATH}")

    # Create safety copy of current DB if exists
    if os.path.exists(DB_PATH):
        safety_path = DB_PATH + ".safety_pre_restore"
        shutil.copy2(DB_PATH, safety_path)
        print(f"[INFO] Created pre-restore safety copy at: {safety_path}")

    shutil.copy2(backup_path, DB_PATH)
    print("[SUCCESS] Database restored successfully.")
    check_integrity()


def list_backups():
    ensure_backup_dir()
    files = [f for f in os.listdir(BACKUP_DIR) if f.endswith(".db")]
    print("=" * 80)
    print(f"  AVAILABLE BACKUPS ({len(files)} found in {BACKUP_DIR})")
    print("=" * 80)
    for f in sorted(files, reverse=True):
        fpath = os.path.join(BACKUP_DIR, f)
        size_kb = os.path.getsize(fpath) / 1024
        mtime = datetime.fromtimestamp(os.path.getmtime(fpath)).strftime("%Y-%m-%d %H:%M:%S")
        print(f"- {f:<40} | {size_kb:>8.2f} KB | {mtime}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python backup_restore.py [backup | check | list | restore <filename>]")
        sys.exit(0)

    cmd = sys.argv[1].lower()
    if cmd == "backup":
        backup()
    elif cmd == "check":
        check_integrity()
    elif cmd == "list":
        list_backups()
    elif cmd == "restore":
        if len(sys.argv) < 3:
            print("Please specify the backup filename to restore: python backup_restore.py restore <filename>")
            sys.exit(1)
        restore(sys.argv[2])
    else:
        print(f"Unknown command: {cmd}")
        print("Usage: python backup_restore.py [backup | check | list | restore <filename>]")


if __name__ == "__main__":
    main()
