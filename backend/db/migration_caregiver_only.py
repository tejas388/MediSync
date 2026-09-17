# backend/db/migration_caregiver_only.py
# MediSync — Migration: Apply Option A caregiver-only schema changes to existing DB
#
# What this migration does:
#   1. Makes firebase_uid nullable (was NOT NULL) — patients have no Firebase account
#   2. Adds created_by column — tracks which caregiver created each patient
#   3. Cleans up synthetic firebase_uids (caregiver_created_* hack) → sets them to NULL
#   4. Changes DEFAULT role to 'caregiver'
#
# Usage:
#   cd backend
#   python db/migration_caregiver_only.py

import os
import psycopg
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / '.env')


def get_conninfo():
    host     = os.getenv('PG_HOST', 'localhost')
    port     = os.getenv('PG_PORT', '5432')
    dbname   = os.getenv('PG_DATABASE', 'medisync')
    user     = os.getenv('PG_USER', 'postgres')
    password = os.getenv('PG_PASSWORD', '')
    ssl      = os.getenv('PG_SSL', 'false').lower() == 'true'
    conninfo = f"host={host} port={port} dbname={dbname} user={user} password={password}"
    if ssl:
        conninfo += " sslmode=require"
    return conninfo


def main():
    conninfo = get_conninfo()
    print('🔄 Running caregiver-only migration on PostgreSQL...\n')

    with psycopg.connect(conninfo, autocommit=True) as conn:

        # ── Step 1: Make firebase_uid nullable ────────────────────────────────
        print('Step 1: Making firebase_uid nullable...')
        try:
            conn.execute("""
                ALTER TABLE users
                ALTER COLUMN firebase_uid DROP NOT NULL;
            """)
            print('  ✅ firebase_uid is now nullable')
        except Exception as e:
            print(f'  ℹ️  Skipped (may already be nullable): {e}')

        # ── Step 2: Add created_by column ─────────────────────────────────────
        print('Step 2: Adding created_by column...')
        try:
            conn.execute("""
                ALTER TABLE users
                ADD COLUMN IF NOT EXISTS created_by UUID
                REFERENCES users (id) ON DELETE SET NULL;
            """)
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_users_created_by
                ON users (created_by) WHERE created_by IS NOT NULL;
            """)
            print('  ✅ created_by column added')
        except Exception as e:
            print(f'  ℹ️  Skipped: {e}')

        # ── Step 3: Fix index on firebase_uid (was full index, now partial) ───
        print('Step 3: Updating firebase_uid index to partial (WHERE NOT NULL)...')
        try:
            conn.execute('DROP INDEX IF EXISTS idx_users_firebase_uid;')
            conn.execute("""
                CREATE UNIQUE INDEX IF NOT EXISTS idx_users_firebase_uid
                ON users (firebase_uid) WHERE firebase_uid IS NOT NULL;
            """)
            print('  ✅ firebase_uid partial index created')
        except Exception as e:
            print(f'  ℹ️  Skipped: {e}')

        # ── Step 4: Fix index on patient_code (partial) ───────────────────────
        print('Step 4: Updating patient_code index to partial (WHERE NOT NULL)...')
        try:
            conn.execute('DROP INDEX IF EXISTS idx_users_patient_code;')
            conn.execute("""
                CREATE UNIQUE INDEX IF NOT EXISTS idx_users_patient_code
                ON users (patient_code) WHERE patient_code IS NOT NULL;
            """)
            print('  ✅ patient_code partial index created')
        except Exception as e:
            print(f'  ℹ️  Skipped: {e}')

        # ── Step 5: Clean up synthetic firebase_uids from old create_patient ──
        print('Step 5: Cleaning up synthetic firebase_uids (caregiver_created_* → NULL)...')
        result = conn.execute("""
            UPDATE users
            SET firebase_uid = NULL
            WHERE firebase_uid LIKE 'caregiver_created_%'
            RETURNING id, name;
        """)
        rows = result.fetchall()
        if rows:
            print(f'  ✅ Cleaned {len(rows)} patient rows:')
            for row in rows:
                print(f'     - {row[1]} ({row[0]})')
        else:
            print('  ℹ️  No synthetic firebase_uids found — nothing to clean')

        # ── Step 6: Change DEFAULT role on users table ────────────────────────
        print('Step 6: Changing default role to caregiver...')
        try:
            conn.execute("""
                ALTER TABLE users
                ALTER COLUMN role SET DEFAULT 'caregiver';
            """)
            print('  ✅ Default role set to caregiver')
        except Exception as e:
            print(f'  ℹ️  Skipped: {e}')

        # ── Step 7: Verify ────────────────────────────────────────────────────
        print('\n📊 Verification:')
        caregivers = conn.execute(
            "SELECT COUNT(*) FROM users WHERE role = 'caregiver'"
        ).fetchone()[0]
        patients = conn.execute(
            "SELECT COUNT(*) FROM users WHERE role = 'patient'"
        ).fetchone()[0]
        null_fb = conn.execute(
            "SELECT COUNT(*) FROM users WHERE firebase_uid IS NULL"
        ).fetchone()[0]
        created_by_set = conn.execute(
            "SELECT COUNT(*) FROM users WHERE created_by IS NOT NULL"
        ).fetchone()[0]

        print(f'  Caregivers in DB : {caregivers}')
        print(f'  Patients in DB   : {patients}')
        print(f'  NULL firebase_uid: {null_fb}')
        print(f'  created_by set   : {created_by_set}')

    print('\n✅ Migration completed successfully!')


if __name__ == '__main__':
    main()
