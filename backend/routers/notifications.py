# backend/routers/notifications.py — psycopg3 (%s placeholders)
import asyncio
from fastapi import APIRouter, Depends, Query
from typing import Optional
from db.database import get_pool
from middleware.auth import get_current_user

router = APIRouter(prefix='/api/v1/notifications', tags=['notifications'])


def row_to_notif(row) -> dict:
    r = dict(row)
    return {
        'id':           str(r['id']),
        'userId':       str(r['user_id']),
        'title':        r['title'],
        'body':         r['body'],
        'type':         r['type'],
        'isRead':       r['is_read'],
        'medicineId':   str(r['medicine_id']) if r['medicine_id'] else None,
        'medicineName': r['medicine_name'],
        'extra':        r['extra'],
        'createdAt':    r['created_at'].isoformat() if r.get('created_at') else None,
    }


@router.get('/')
async def get_notifications(
    unread: Optional[str] = Query(None),
    page:   int           = Query(1),
    limit:  int           = Query(20),
    user: dict = Depends(get_current_user),
):
    pool   = get_pool()
    conds  = ['user_id = %s']
    values = [user['id']]
    if unread == 'true':
        conds.append('is_read = FALSE')
    where  = ' AND '.join(conds)
    offset = (page - 1) * limit

    total, rows, unread_count = await asyncio.gather(
        pool.fetchval(f'SELECT COUNT(*) FROM notifications WHERE {where}', *values),
        pool.fetch(
            f'SELECT * FROM notifications WHERE {where} ORDER BY created_at DESC LIMIT %s OFFSET %s',
            *values, limit, offset,
        ),
        pool.fetchval('SELECT COUNT(*) FROM notifications WHERE user_id = %s AND is_read = FALSE', user['id']),
    )
    return {
        'success': True, 'data': [row_to_notif(r) for r in rows],
        'total': total, 'unreadCount': unread_count,
    }


@router.patch('/{notif_id}/read')
async def mark_read(notif_id: str, user: dict = Depends(get_current_user)):
    pool = get_pool()
    await pool.execute('UPDATE notifications SET is_read = TRUE WHERE id = %s AND user_id = %s', notif_id, user['id'])
    return {'success': True}


@router.patch('/read-all')
async def mark_all_read(user: dict = Depends(get_current_user)):
    pool = get_pool()
    await pool.execute('UPDATE notifications SET is_read = TRUE WHERE user_id = %s AND is_read = FALSE', user['id'])
    return {'success': True}


@router.delete('/{notif_id}')
async def delete_notification(notif_id: str, user: dict = Depends(get_current_user)):
    pool = get_pool()
    await pool.execute('DELETE FROM notifications WHERE id = %s AND user_id = %s', notif_id, user['id'])
    return {'success': True}
