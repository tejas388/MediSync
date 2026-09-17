# backend/services/scheduler.py
# MediSync - APScheduler cron jobs — psycopg3 version (%s placeholders)

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from datetime import datetime, date
from db.database import get_pool
from services.notification import create_notification
from config.firebase import send_fcm_multicast

_scheduler = AsyncIOScheduler()


from zoneinfo import ZoneInfo

def fmt_time(dt: datetime) -> str:
    # If dt is naive, we could attach timezone, but strftime works
    return dt.strftime('%I:%M %p')


async def reminder_job(sio):
    try:
        pool     = get_pool()
        ist      = ZoneInfo('Asia/Kolkata')
        now      = datetime.now(ist)
        time_str = now.strftime('%H:%M')

        rows = await pool.fetch(
            """SELECT m.*, u.id AS u_id, u.email AS u_email,
                      u.fcm_token AS u_fcm_token, u.device_id AS u_device_id
               FROM medicines m JOIN users u ON u.id = m.user_id
               WHERE m.is_active = TRUE
                 AND %s = ANY(m.reminder_times)
                 AND m.start_date <= CURRENT_DATE
                 AND (m.end_date IS NULL OR m.end_date >= CURRENT_DATE)""",
            time_str,
        )

        for med in rows:
            user_id   = str(med['u_id'])
            fcm_token = med['u_fcm_token']
            device_id = med['u_device_id']
            
            scheduled_time = now.replace(second=0, microsecond=0)

            existing = await pool.fetchrow(
                """SELECT id, status FROM dose_records
                   WHERE medicine_id = %s AND user_id = %s
                     AND scheduled_time = %s
                   LIMIT 1""",
                str(med['id']), user_id, scheduled_time,
            )
            if existing:
                dose_id = existing['id']
                if existing['status'] != 'pending':
                    continue
            else:
                row = await pool.fetchrow(
                    """INSERT INTO dose_records
                         (user_id, medicine_id, medicine_name, dosage,
                          scheduled_time, status, dispenser_compartment)
                       VALUES (%s, %s, %s, %s, %s, 'pending', %s) RETURNING id""",
                    user_id, str(med['id']), med['name'], med['dosage'],
                    scheduled_time, med['compartment_number'],
                )
                dose_id = row['id']

            await create_notification(user_id, {
                'title':        f"💊 Time for {med['name']}",
                'body':         f"Take your {med['dosage']} dose now. {med['food_instruction']}.",
                'type':         'doseReminder',
                'medicineId':   str(med['id']),
                'medicineName': med['name'],
                'doseId':       str(dose_id),
            }, fcm_token)

            if device_id:
                await sio.emit('dispense:scheduled', {
                    'compartmentNumber': med['compartment_number'],
                    'medicineName':      med['name'],
                    'scheduledTime':     scheduled_time.isoformat(),
                }, room=f'device:{device_id}')

            print(f"[Scheduler] Reminder: {med['name']} → {med['u_email']}")

    except Exception as e:
        print(f'[Scheduler] Reminder job error: {e}')


async def missed_dose_job(sio):
    try:
        pool   = get_pool()
        missed = await pool.fetch(
            """UPDATE dose_records SET status = 'missed'
               WHERE status = 'pending' AND scheduled_time <= NOW() - INTERVAL '1 hour'
               RETURNING *"""
        )

        for dose in missed:
            user_id = str(dose['user_id'])
            patient = await pool.fetchrow(
                'SELECT fcm_token, name FROM users WHERE id = %s LIMIT 1', str(dose['user_id'])
            )
            fcm_token = patient['fcm_token'] if patient else None

            await create_notification(user_id, {
                'title':        '⚠️ Missed Dose',
                'body':         f"You missed your {dose['medicine_name']} dose at {fmt_time(dose['scheduled_time'])}.",
                'type':         'doseMissed',
                'medicineName': dose['medicine_name'],
            }, fcm_token)

            caregivers = await pool.fetch(
                """SELECT u.fcm_token FROM caregiver_patient_links cpl
                   JOIN users u ON u.id = cpl.caregiver_id
                   WHERE cpl.patient_id = %s AND u.fcm_token IS NOT NULL""",
                str(dose['user_id']),
            )
            tokens = [c['fcm_token'] for c in caregivers]
            if tokens:
                patient_name = patient['name'] if patient else 'Patient'
                await send_fcm_multicast(
                    tokens, '⚠️ Patient Missed Dose',
                    f"{patient_name} missed their {dose['medicine_name']} dose.",
                    {'patientId': user_id, 'doseId': str(dose['id']), 'type': 'doseMissed'},
                )

        if missed:
            print(f'[Scheduler] Marked {len(missed)} doses as missed')

    except Exception as e:
        print(f'[Scheduler] Missed-dose job error: {e}')


async def daily_alerts_job():
    try:
        pool = get_pool()
        expiring = await pool.fetch(
            """SELECT m.*, u.fcm_token AS u_fcm_token, u.id AS u_id
               FROM medicines m JOIN users u ON u.id = m.user_id
               WHERE m.is_active = TRUE
                 AND m.expiry_date BETWEEN NOW() AND NOW() + INTERVAL '30 days'"""
        )
        low_stock = await pool.fetch(
            """SELECT m.*, u.fcm_token AS u_fcm_token, u.id AS u_id
               FROM medicines m JOIN users u ON u.id = m.user_id
               WHERE m.is_active = TRUE AND m.quantity < 5"""
        )

        for med in expiring:
            days_left = (med['expiry_date'] - date.today()).days
            await create_notification(str(med['u_id']), {
                'title':        '📅 Expiry Alert',
                'body':         f"{med['name']} expires in {days_left} day{'s' if days_left != 1 else ''}.",
                'type':         'expiryAlert',
                'medicineId':   str(med['id']),
                'medicineName': med['name'],
            }, med['u_fcm_token'])

        for med in low_stock:
            await create_notification(str(med['u_id']), {
                'title':        '📦 Low Stock',
                'body':         f"{med['name']} has only {med['quantity']} tablet(s) left.",
                'type':         'lowStock',
                'medicineId':   str(med['id']),
                'medicineName': med['name'],
            }, med['u_fcm_token'])

        print(f'[Scheduler] Daily alerts: {len(expiring)} expiry, {len(low_stock)} low stock')
    except Exception as e:
        print(f'[Scheduler] Daily alert job error: {e}')


def setup_scheduler(sio):
    _scheduler.add_job(reminder_job,     'cron', minute='*',    args=[sio])
    _scheduler.add_job(missed_dose_job,  'cron', minute='*/15', args=[sio])
    _scheduler.add_job(daily_alerts_job, 'cron', hour=8, minute=0)
    _scheduler.start()
    print('✅ Scheduler service started')


def stop_scheduler():
    if _scheduler.running:
        _scheduler.shutdown()
