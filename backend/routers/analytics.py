# backend/routers/analytics.py — psycopg3 (%s placeholders)
import asyncio
from fastapi import APIRouter, Depends, Query
from datetime import datetime, timedelta, date
from db.database import get_pool
from middleware.auth import get_current_user

router = APIRouter(prefix='/api/v1/analytics', tags=['analytics'])


@router.get('/adherence')
async def get_adherence(days: int = Query(7), user: dict = Depends(get_current_user)):
    pool = get_pool()
    rows = await pool.fetch(
        """SELECT status, scheduled_time FROM dose_records
           WHERE user_id = %s AND status IN ('taken','missed')
             AND scheduled_time >= NOW() - (%s || ' days')::INTERVAL""",
        user['id'], str(days),
    )
    total  = len(rows)
    taken  = sum(1 for r in rows if r['status'] == 'taken')
    missed = total - taken
    rate   = round((taken / total) * 100) if total > 0 else 0

    daily_map = {}
    for i in range(days):
        day = (datetime.utcnow() - timedelta(days=(days - 1 - i))).date()
        key = day.isoformat()
        daily_map[key] = {'date': key, 'taken': 0, 'missed': 0, 'total': 0}
    for r in rows:
        key = r['scheduled_time'].date().isoformat()
        if key in daily_map:
            daily_map[key]['total'] += 1
            daily_map[key][r['status']] += 1

    return {
        'success': True,
        'data': {
            'period': f'{days} days', 'totalDoses': total,
            'takenDoses': taken, 'missedDoses': missed,
            'adherenceRate': rate, 'daily': list(daily_map.values()),
        },
    }


@router.get('/per-medicine')
async def get_per_medicine_stats(user: dict = Depends(get_current_user)):
    pool = get_pool()
    rows = await pool.fetch(
        """SELECT
             medicine_id::text                                          AS "medicineId",
             MAX(medicine_name)                                         AS "medicineName",
             COUNT(*)::int                                              AS total,
             SUM(CASE WHEN status='taken'  THEN 1 ELSE 0 END)::int     AS taken,
             SUM(CASE WHEN status='missed' THEN 1 ELSE 0 END)::int     AS missed,
             ROUND(SUM(CASE WHEN status='taken' THEN 1 ELSE 0 END)::numeric
                   / GREATEST(COUNT(*),1) * 100)::int                  AS "adherenceRate"
           FROM dose_records
           WHERE user_id = %s AND scheduled_time >= NOW() - INTERVAL '30 days'
           GROUP BY medicine_id ORDER BY "adherenceRate" ASC""",
        user['id'],
    )
    return {'success': True, 'data': [dict(r) for r in rows]}


@router.get('/streak')
async def get_streak(user: dict = Depends(get_current_user)):
    pool = get_pool()
    rows = await pool.fetch(
        """SELECT
             TO_CHAR(scheduled_time AT TIME ZONE 'UTC','YYYY-MM-DD') AS day,
             COUNT(*)::int                                            AS total,
             SUM(CASE WHEN status='taken' THEN 1 ELSE 0 END)::int   AS taken
           FROM dose_records
           WHERE user_id = %s AND status IN ('taken','missed')
             AND scheduled_time >= NOW() - INTERVAL '90 days'
           GROUP BY day ORDER BY day DESC""",
        user['id'],
    )
    current_streak = longest_streak = temp_streak = 0
    last_day = None
    for r in rows:
        perfect = r['taken'] == r['total'] and r['total'] > 0
        if perfect:
            if last_day is None or abs((date.fromisoformat(last_day) - date.fromisoformat(r['day'])).days) == 1:
                temp_streak += 1; current_streak = temp_streak
            else:
                temp_streak = 1
        else:
            longest_streak = max(longest_streak, temp_streak); temp_streak = 0
        last_day = r['day']
    longest_streak = max(longest_streak, temp_streak)
    return {'success': True, 'data': {'currentStreak': current_streak, 'longestStreak': longest_streak}}


@router.get('/summary')
async def get_summary(user: dict = Depends(get_current_user)):
    pool = get_pool()
    today_row, meds_row = await asyncio.gather(
        pool.fetchrow(
            """SELECT COUNT(*)::int AS total,
                      SUM(CASE WHEN status='taken'   THEN 1 ELSE 0 END)::int AS taken,
                      SUM(CASE WHEN status='missed'  THEN 1 ELSE 0 END)::int AS missed,
                      SUM(CASE WHEN status='pending' THEN 1 ELSE 0 END)::int AS pending
               FROM dose_records
               WHERE user_id = %s
                 AND scheduled_time >= date_trunc('day', NOW())
                 AND scheduled_time <  date_trunc('day', NOW()) + INTERVAL '1 day'""",
            user['id'],
        ),
        pool.fetchrow(
            """SELECT COUNT(*)::int AS active,
                      SUM(CASE WHEN quantity < 5 THEN 1 ELSE 0 END)::int AS low_stock,
                      SUM(CASE WHEN expiry_date BETWEEN NOW() AND NOW()+INTERVAL '30 days'
                               THEN 1 ELSE 0 END)::int AS expiring_soon
               FROM medicines WHERE user_id = %s AND is_active = TRUE""",
            user['id'],
        ),
    )
    t = dict(today_row)
    m = dict(meds_row)
    return {
        'success': True,
        'data': {
            'today': {
                'total': t['total'], 'taken': t['taken'], 'missed': t['missed'], 'pending': t['pending'],
                'adherence': round((t['taken'] / t['total']) * 100) if t['total'] else 100,
            },
            'medicines': {'active': m['active'], 'lowStock': m['low_stock'], 'expiringSoon': m['expiring_soon']},
        },
    }
