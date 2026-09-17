import asyncio
from backend.db.database import init_pool, get_pool, close_pool

async def main():
    await init_pool()
    pool = get_pool()
    doses = await pool.fetch("SELECT id, medicine_id, status, scheduled_time FROM dose_records")
    for d in doses:
        print(dict(d))
    
    print("---")
    meds = await pool.fetch("SELECT id, name, quantity FROM medicines")
    for m in meds:
        print(dict(m))
    await close_pool()

asyncio.run(main())
