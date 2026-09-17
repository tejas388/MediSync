# backend/db/init.py
# MediSync — One-shot schema runner (psycopg3 version)
# Usage: python db/init.py

import os
import psycopg
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / '.env')


def main():
    schema_path = Path(__file__).parent / 'schema.sql'
    sql = schema_path.read_text(encoding='utf-8')

    host     = os.getenv('PG_HOST', 'localhost')
    port     = os.getenv('PG_PORT', '5432')
    dbname   = os.getenv('PG_DATABASE', 'medisync')
    user     = os.getenv('PG_USER', 'postgres')
    password = os.getenv('PG_PASSWORD', '')
    ssl      = os.getenv('PG_SSL', 'false').lower() == 'true'
    conninfo = f"host={host} port={port} dbname={dbname} user={user} password={password}"
    if ssl:
        conninfo += " sslmode=require"

    print('🔄 Running schema.sql against PostgreSQL...')
    try:
        with psycopg.connect(conninfo, autocommit=True) as conn:
            conn.execute(sql)
        print('✅ Schema applied successfully!')
    except Exception as e:
        print(f'❌ Schema init failed: {e}')
        raise


if __name__ == '__main__':
    main()
