# backend/services/notification.py
import json
from db.database import get_pool
from config.firebase import send_fcm_notification


async def create_notification(user_id: str, data: dict, fcm_token: str = None):
    try:
        pool  = get_pool()
        extra = json.dumps(data['extra']) if data.get('extra') else None

        row = await pool.fetchrow(
            """INSERT INTO notifications
                 (user_id, title, body, type, medicine_id, medicine_name, extra)
               VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING *""",
            user_id, data.get('title'), data.get('body'), data.get('type'),
            data.get('medicineId'), data.get('medicineName'), extra,
        )

        if fcm_token and data.get('title') and data.get('body'):
            await send_fcm_notification(
                fcm_token, data['title'], data['body'],
                {'type': data.get('type', 'general'), 'notifId': str(row['id'])},
            )
        return dict(row)
    except Exception as e:
        print(f'[NotificationService] error: {e}')
