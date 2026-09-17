# backend/db/database.py
# MediSync - psycopg3 async pool with asyncpg-compatible wrapper

import os
from typing import Optional
import psycopg
from psycopg.rows import dict_row
from psycopg_pool import AsyncConnectionPool

_pool: Optional[AsyncConnectionPool] = None


def _build_conninfo() -> str:
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


async def init_pool():
    global _pool
    conninfo = _build_conninfo()
    _pool = AsyncConnectionPool(
        conninfo,
        min_size=int(os.getenv('PG_POOL_MIN', 5)),          # pre-open 5 connections at startup
        max_size=int(os.getenv('PG_POOL_MAX', 20)),          # allow up to 20 concurrent connections
        open=False,
        reconnect_timeout=float(os.getenv('PG_RECONNECT_TIMEOUT', 5)),  # fast reconnect
        kwargs={
            'connect_timeout': int(os.getenv('PG_CONNECT_TIMEOUT', 5)),  # fail fast if DB unreachable
            'options': '-c statement_timeout=30000',                       # 30s statement timeout
            'keepalives': 1,
            'keepalives_idle': 30,
            'keepalives_interval': 10,
            'keepalives_count': 5,
            'application_name': 'medisync_api',
        },
    )
    await _pool.open()
    # Quick connectivity test
    async with _pool.connection() as conn:
        await conn.execute('SELECT 1')
    print('[OK] PostgreSQL connected (psycopg3 pool ready)')


async def close_pool():
    global _pool
    if _pool:
        await _pool.close()
        print('[PostgreSQL] Pool closed')


class _PoolWrapper:
    """asyncpg-compatible interface over psycopg3 AsyncConnectionPool.
    
    Routers call pool.fetch / pool.fetchrow / pool.execute / pool.fetchval
    with %s placeholders — identical API to asyncpg except placeholder style.
    """

    def __init__(self, inner: AsyncConnectionPool):
        self._pool = inner

    async def fetch(self, query: str, *args) -> list[dict]:
        async with self._pool.connection() as conn:
            async with conn.cursor(row_factory=dict_row) as cur:
                await cur.execute(query, args or None)
                return await cur.fetchall()

    async def fetchrow(self, query: str, *args) -> Optional[dict]:
        async with self._pool.connection() as conn:
            async with conn.cursor(row_factory=dict_row) as cur:
                await cur.execute(query, args or None)
                return await cur.fetchone()

    async def execute(self, query: str, *args):
        async with self._pool.connection() as conn:
            await conn.execute(query, args or None)

    async def fetchval(self, query: str, *args):
        async with self._pool.connection() as conn:
            async with conn.cursor() as cur:
                await cur.execute(query, args or None)
                row = await cur.fetchone()
                return row[0] if row else None


_wrapper: Optional[_PoolWrapper] = None


def get_pool() -> _PoolWrapper:
    global _wrapper, _pool
    if _wrapper is None:
        if _pool is None:
            raise RuntimeError('Database pool not initialized. Call init_pool() first.')
        _wrapper = _PoolWrapper(_pool)
    return _wrapper
