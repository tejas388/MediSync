# backend/routers/doses.py — psycopg3 (%s placeholders)
from fastapi import APIRouter, Depends, Query, HTTPException
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from db.database import get_pool
from middleware.auth import get_current_user
from config.firebase import send_fcm_multicast
import re

router = APIRouter(prefix='/api/v1/doses', tags=['doses'])


def row_to_dose(row) -> dict:
    if not row:
        return None
    r = dict(row)
    return {
        'id':                   str(r['id']),
        'userId':               str(r['user_id']),
        'medicineId':           str(r['medicine_id']),
        'medicineName':         r['medicine_name'],
        'dosage':               r['dosage'],
        'scheduledTime':        r['scheduled_time'].isoformat() if r['scheduled_time'] else None,
        'takenTime':            r['taken_time'].isoformat()     if r['taken_time']     else None,
        'status':               r['status'],
        'dispensedByDevice':    r['dispensed_by_device'],
        'dispenserCompartment': r['dispenser_compartment'],
        'snoozedCount':         r['snoozed_count'],
        'notes':                r['notes'],
        'createdAt':            r['created_at'].isoformat() if r.get('created_at') else None,
    }


class CreateDoseBody(BaseModel):
    medicineId:           str
    medicineName:         str
    dosage:               str
    scheduledTime:        datetime
    status:               str           = 'pending'
    dispenserCompartment: Optional[int] = None


class MarkTakenBody(BaseModel):
    takenTime: Optional[datetime] = None


class SnoozeBody(BaseModel):
    minutes: int = 10


@router.get('/')
async def get_doses(
    status:     Optional[str] = Query(None),
    from_date:  Optional[str] = Query(None, alias='from'),
    to_date:    Optional[str] = Query(None, alias='to'),
    medicineId: Optional[str] = Query(None),
    page:       int           = Query(1),
    limit:      int           = Query(20),
    user: dict = Depends(get_current_user),
):
    pool   = get_pool()
    conds = ['(user_id = %s OR user_id IN (SELECT patient_id FROM caregiver_patient_links WHERE caregiver_id = %s))']
    values = [user['id'], user['id']]
    if status:     conds.append('status = %s');           values.append(status)
    if medicineId: conds.append('medicine_id = %s');      values.append(medicineId)
    if from_date:  conds.append('scheduled_time >= %s');  values.append(datetime.fromisoformat(from_date))
    if to_date:    conds.append('scheduled_time <= %s');  values.append(datetime.fromisoformat(to_date))

    where  = ' AND '.join(conds)
    offset = (page - 1) * limit
    total  = await pool.fetchval(f'SELECT COUNT(*) FROM dose_records WHERE {where}', *values)
    rows   = await pool.fetch(
        f'SELECT * FROM dose_records WHERE {where} ORDER BY scheduled_time DESC LIMIT %s OFFSET %s',
        *values, limit, offset,
    )
    return {
        'success': True,
        'data':    [row_to_dose(r) for r in rows],
        'pagination': {'total': total, 'page': page, 'limit': limit, 'pages': -(-total // limit)},
    }


from zoneinfo import ZoneInfo

@router.get('/today')
async def get_today_doses(user: dict = Depends(get_current_user)):
    pool = get_pool()
    ist = ZoneInfo('Asia/Kolkata')
    now = datetime.now(ist)
    
    # Generate doses for the rest of today that haven't been created yet
    active_meds = await pool.fetch(
        """SELECT * FROM medicines 
           WHERE user_id = %s AND is_active = TRUE 
             AND start_date <= CURRENT_DATE 
             AND (end_date IS NULL OR end_date >= CURRENT_DATE)""",
        user['id']
    )
    for med in active_meds:
        for t_str in med.get('reminder_times', []):
            try:
                hr, mn = map(int, t_str.split(':'))
                sched_time = now.replace(hour=hr, minute=mn, second=0, microsecond=0)
                
                # We only want to generate doses for today
                existing = await pool.fetchrow(
                    """SELECT id FROM dose_records 
                       WHERE medicine_id = %s AND user_id = %s 
                         AND scheduled_time = %s""",
                    str(med['id']), user['id'], sched_time
                )
                if not existing:
                    await pool.execute(
                        """INSERT INTO dose_records
                             (user_id, medicine_id, medicine_name, dosage,
                              scheduled_time, status, dispenser_compartment)
                           VALUES (%s, %s, %s, %s, %s, 'pending', %s)""",
                        user['id'], str(med['id']), med['name'], med['dosage'],
                        sched_time, med['compartment_number']
                    )
            except Exception as e:
                print(f"[get_today_doses] error generating early dose: {e}")
                
    # Since scheduled_time is AT TIME ZONE, we can just compare to local today bounds
    start_of_day = now.replace(hour=0, minute=0, second=0, microsecond=0)
    end_of_day = now.replace(hour=23, minute=59, second=59, microsecond=999999)
    
    rows = await pool.fetch(
        """SELECT * FROM dose_records
           WHERE user_id = %s
             AND scheduled_time >= %s
             AND scheduled_time <= %s
           ORDER BY scheduled_time ASC""",
        user['id'], start_of_day, end_of_day
    )
    return {'success': True, 'data': [row_to_dose(r) for r in rows]}


@router.get('/history')
async def get_dose_history(
    page: int = Query(1, ge=1),
    limit: int = Query(25, ge=1, le=100),
    status: Optional[str] = Query(None),
    user: dict = Depends(get_current_user),
):
    pool = get_pool()

    conds = ['(user_id = %s OR user_id IN (SELECT patient_id FROM caregiver_patient_links WHERE caregiver_id = %s))']
    values = [user['id'], user['id']]

    if status:
        conds.append('status = %s')
        values.append(status)

    where = ' AND '.join(conds)

    offset = (page - 1) * limit

    total = await pool.fetchval(
        f'SELECT COUNT(*) FROM dose_records WHERE {where}',
        *values,
    )

    rows = await pool.fetch(
        f"""
        SELECT *
        FROM dose_records
        WHERE {where}
        ORDER BY scheduled_time DESC
        LIMIT %s OFFSET %s
        """,
        *values,
        limit,
        offset,
    )

    return {
        'success': True,
        'data': [row_to_dose(r) for r in rows],
        'pagination': {
            'total': total,
            'page': page,
            'limit': limit,
            'pages': -(-total // limit) if total else 0,
        },
    }


@router.post('/', status_code=201)
async def create_dose(body: CreateDoseBody, user: dict = Depends(get_current_user)):
    pool = get_pool()
    row  = await pool.fetchrow(
        """INSERT INTO dose_records
             (user_id, medicine_id, medicine_name, dosage,
              scheduled_time, status, dispenser_compartment)
           VALUES (%s,%s,%s,%s,%s,%s,%s) RETURNING *""",
        user['id'], body.medicineId, body.medicineName, body.dosage,
        body.scheduledTime, body.status, body.dispenserCompartment,
    )
    return {'success': True, 'data': row_to_dose(row)}


@router.patch('/{dose_id}/take')
async def mark_taken(dose_id: str, body: MarkTakenBody, user: dict = Depends(get_current_user)):
    pool     = get_pool()
    taken_at = body.takenTime or datetime.utcnow()
    row      = await pool.fetchrow(
        """UPDATE dose_records SET status = 'taken', taken_time = %s 
           WHERE id = %s 
             AND (user_id = %s OR user_id IN (SELECT patient_id FROM caregiver_patient_links WHERE caregiver_id = %s))
           RETURNING *""",
        taken_at, dose_id, user['id'], user['id'],
    )
    if not row:
        # Fallback: maybe dose_id is actually a medicine_id (from local notification)
        row = await pool.fetchrow(
            """UPDATE dose_records SET status = 'taken', taken_time = %s 
               WHERE id = (
                   SELECT id FROM dose_records 
                   WHERE medicine_id = %s 
                     AND (user_id = %s OR user_id IN (SELECT patient_id FROM caregiver_patient_links WHERE caregiver_id = %s))
                     AND status = 'pending'
                   ORDER BY scheduled_time ASC LIMIT 1
               ) RETURNING *""",
            taken_at, dose_id, user['id'], user['id']
        )
        if not row:
            raise HTTPException(status_code=404, detail='Dose not found (or no pending dose for this medicine)')
    
    # Reduce stock by the prescribed number of tablets/pills.
    dosage_text = str(row['dosage'] or '1')
    dosage_match = re.search(r'\d+(?:\.\d+)?', dosage_text)
    dose_quantity = int(float(dosage_match.group(0))) if dosage_match else 1
    dose_quantity = max(dose_quantity, 1)

    await pool.execute(
        '''UPDATE medicines
           SET quantity = GREATEST(quantity - %s, 0)
           WHERE id = %s''',
        dose_quantity,
        str(row['medicine_id']),
    )
    return {'success': True, 'data': row_to_dose(row)}


@router.patch('/{dose_id}/snooze')
async def snooze_dose(dose_id: str, body: SnoozeBody, user: dict = Depends(get_current_user)):
    pool = get_pool()
    row  = await pool.fetchrow(
        """UPDATE dose_records
           SET status = 'snoozed',
               snoozed_count  = snoozed_count + 1,
               scheduled_time = scheduled_time + (%s * INTERVAL '1 minute')
           WHERE id = %s 
             AND (user_id = %s OR user_id IN (SELECT patient_id FROM caregiver_patient_links WHERE caregiver_id = %s))
           RETURNING *""",
        body.minutes, dose_id, user['id'], user['id'],
    )
    if not row:
        row = await pool.fetchrow(
            """UPDATE dose_records
               SET status = 'snoozed',
                   snoozed_count  = snoozed_count + 1,
                   scheduled_time = scheduled_time + (%s * INTERVAL '1 minute')
               WHERE id = (
                   SELECT id FROM dose_records 
                   WHERE medicine_id = %s 
                     AND (user_id = %s OR user_id IN (SELECT patient_id FROM caregiver_patient_links WHERE caregiver_id = %s))
                     AND status = 'pending'
                   ORDER BY scheduled_time ASC LIMIT 1
               ) RETURNING *""",
            body.minutes, dose_id, user['id'], user['id']
        )
        if not row:
            raise HTTPException(status_code=404, detail='Dose not found (or no pending dose for this medicine)')
    dose = row_to_dose(row)
    return {'success': True, 'data': dose, 'nextReminder': dose['scheduledTime']}


@router.patch('/{dose_id}/miss')
async def mark_missed(dose_id: str, user: dict = Depends(get_current_user)):
    pool = get_pool()
    row  = await pool.fetchrow(
        "UPDATE dose_records SET status = 'missed' WHERE id = %s AND user_id = %s RETURNING *",
        dose_id, user['id'],
    )
    if not row:
        raise HTTPException(status_code=404, detail='Dose not found')
    dose       = row_to_dose(row)
    caregivers = await pool.fetch(
        """SELECT u.fcm_token FROM caregiver_patient_links cpl
           JOIN users u ON u.id = cpl.caregiver_id
           WHERE cpl.patient_id = %s AND u.fcm_token IS NOT NULL""",
        user['id'],
    )
    tokens = [c['fcm_token'] for c in caregivers]
    if tokens:
        t = datetime.fromisoformat(dose['scheduledTime']).strftime('%I:%M %p')
        await send_fcm_multicast(
            tokens, '⚠️ Missed Dose Alert',
            f"{user['name']} missed their {dose['medicineName']} dose at {t}",
            {'patientId': user['id'], 'doseId': dose['id']},
        )
    return {'success': True, 'data': dose}
