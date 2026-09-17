#!/usr/bin/env python3
# backend/db/migration_add_patient_code.py
# MediSync -- Safe migration: adds patient_code column and backfills existing users.
#
# Usage:
#   cd backend
#   python db/migration_add_patient_code.py
#
# This script is idempotent -- safe to run multiple times.
# It will NOT delete or modify any existing user data.

import os
import random
import string
import psycopg
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / '.env')


def _conninfo() -> str:
    host     = os.getenv('PG_HOST', 'localhost')
    port     = os.getenv('PG_PORT', '5432')
    dbname   = os.getenv('PG_DATABASE', 'medisync')
    user     = os.getenv('PG_USER', 'postgres')
    password = os.getenv('PG_PASSWORD', '')
    ssl      = os.getenv('PG_SSL', 'false').lower() == 'true'
    info     = f"host={host} port={port} dbname={dbname} user={user} password={password}"
    if ssl:
        info += " sslmode=require"
    return info


def _generate_patient_code(existing_codes: set) -> str:
    """Generate a unique MED-XXXXXX code (6 uppercase alphanumeric chars)."""
    chars = string.ascii_uppercase + string.digits
    while True:
        suffix = ''.join(random.choices(chars, k=6))
        code = f"MED-{suffix}"
        if code not in existing_codes:
            existing_codes.add(code)
            return code


def main():
    print("[*] MediSync migration: adding patient_code column...")
    conninfo = _conninfo()

    with psycopg.connect(conninfo, autocommit=True) as conn:
        # -- Step 1: Add the column if it doesn't exist ----------------------
        conn.execute("""
            ALTER TABLE users
            ADD COLUMN IF NOT EXISTS patient_code TEXT UNIQUE
        """)
        print("  [OK] Column patient_code added (or already exists).")

        # -- Step 2: Add index if it doesn't exist ---------------------------
        conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_users_patient_code ON users (patient_code)
        """)
        print("  [OK] Index idx_users_patient_code ensured.")

        # -- Step 3: Fetch all existing patient_code values ------------------
        rows = conn.execute("SELECT patient_code FROM users WHERE patient_code IS NOT NULL").fetchall()
        existing_codes = {r[0] for r in rows}
        print(f"  [i]  {len(existing_codes)} existing patient codes found.")

        # -- Step 4: Backfill every user that currently has NULL patient_code -
        #    We assign codes to ALL users regardless of role so that:
        #    - If a user's role later changes, they already have a code.
        #    - Caregivers with a code simply don't display it in the UI.
        null_rows = conn.execute(
            "SELECT id FROM users WHERE patient_code IS NULL ORDER BY created_at"
        ).fetchall()

        if not null_rows:
            print("  [OK] All users already have patient codes. Nothing to backfill.")
        else:
            print(f"  [*] Backfilling {len(null_rows)} users...")
            for (user_id,) in null_rows:
                code = _generate_patient_code(existing_codes)
                conn.execute(
                    "UPDATE users SET patient_code = %s WHERE id = %s",
                    (code, user_id),
                )
            print(f"  [OK] Backfilled {len(null_rows)} users with MED-XXXXXX codes.")

        # -- Step 5: Verify --------------------------------------------------
        total     = conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
        with_code = conn.execute("SELECT COUNT(*) FROM users WHERE patient_code IS NOT NULL").fetchone()[0]
        print(f"\n  [i] Summary: {with_code}/{total} users now have a patient_code.")
        if total != with_code:
            print(f"  [WARN] {total - with_code} users still missing a code!")
        else:
            print("  [OK] Migration complete -- all users have a patient_code.")


if __name__ == '__main__':
    main()

