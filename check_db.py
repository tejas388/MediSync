import asyncio
from backend.db.database import init_pool, get_pool

async def main():
    await init_pool()

    print("\nDATABASE CONNECTION:")
    print(await get_pool().fetch(
        "SELECT current_database(), current_user, current_schema()"
    ))

    print("\nTABLES:")
    print(await get_pool().fetch(
        "SELECT table_name "
        "FROM information_schema.tables "
        "WHERE table_schema='public' "
        "ORDER BY table_name"
    ))

asyncio.run(main())
