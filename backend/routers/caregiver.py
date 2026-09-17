# backend/routers/caregiver.py — psycopg3 (%s placeholders)
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from typing import Optional, List
from datetime import date, datetime
from db.database import get_pool
from middleware.auth import get_current_user, row_to_user
from config.firebase import send_fcm_notification

router = APIRouter(prefix='/api/v1/caregiver', tags=['caregiver'])


def _row_to_med(row) -> dict:
    r = dict(row)
    expiry = r.get('expiry_date')
    today  = date.today()
    return {
        'id': str(r['id']), 'userId': str(r['user_id']),
        'name': r['name'], 'dosage': r['dosage'], 'quantity': r['quantity'],
        'reminderTimes': r['reminder_times'],
        'startDate': r['start_date'].isoformat() if r['start_date'] else None,
        'endDate':   r['end_date'].isoformat()   if r['end_date']   else None,
        'expiryDate': expiry.isoformat()          if expiry          else None,
        'compartmentNumber': r['compartment_number'],
        'foodInstruction': r['food_instruction'],
        'notes': r['notes'], 'isActive': r['is_active'], 'color': r['color'],
        'isLowStock': r['quantity'] < 5,
        'isExpired': (expiry < today) if expiry else False,
    }

def _row_to_dose(row) -> dict:
    r = dict(row)
    return {
        'id': str(r['id']), 'userId': str(r['user_id']),
        'medicineId': str(r['medicine_id']), 'medicineName': r['medicine_name'],
        'dosage': r['dosage'],
        'scheduledTime': r['scheduled_time'].isoformat() if r['scheduled_time'] else None,
        'takenTime':     r['taken_time'].isoformat()     if r['taken_time']     else None,
        'status': r['status'], 'snoozedCount': r['snoozed_count'],
    }

async def _check_access(caregiver_id: str, patient_id: str) -> bool:
    pool = get_pool()
    row  = await pool.fetchrow(
        'SELECT 1 FROM caregiver_patient_links WHERE caregiver_id = %s AND patient_id = %s',
        caregiver_id, patient_id,
    )
    return row is not None


class LinkBody(BaseModel):
    # Accept the public MediSync Patient ID (MED-XXXXXX format).
    # The backend resolves this to the internal PostgreSQL UUID.
    patientCode: str

class CreatePatientBody(BaseModel):
    name:        str
    phoneNumber: Optional[str] = None
    email:       Optional[str] = None

class AddMedBody(BaseModel):
    name:              str
    dosage:            str
    quantity:          int            = 0
    reminderTimes:     List[str]      = []
    startDate:         date
    endDate:           Optional[date] = None
    expiryDate:        Optional[date] = None
    compartmentNumber: int
    foodInstruction:   str            = 'No restriction'
    notes:             Optional[str]  = None
    color:             str            = '#0A7EA4'


@router.get('/patients')
async def get_patients(user: dict = Depends(get_current_user)):
    pool = get_pool()
    rows = await pool.fetch(
        """SELECT u.* FROM caregiver_patient_links cpl
           JOIN users u ON u.id = cpl.patient_id WHERE cpl.caregiver_id = %s""",
        user['id'],
    )
    patients = []
    for r in rows:
        p_dict = {k: v for k, v in row_to_user(r).items() if k != 'fcmToken'}
        meds = await pool.fetch(
            'SELECT name, compartment_number FROM medicines WHERE user_id = %s AND is_active = TRUE',
            str(r['id'])
        )
        p_dict['activeMedicines'] = [{'name': m['name'], 'compartmentNumber': m['compartment_number']} for m in meds]
        patients.append(p_dict)
    return {'success': True, 'data': patients}


@router.post('/link')
async def link_patient(body: LinkBody, user: dict = Depends(get_current_user)):
    """
    Link a patient to this caregiver using the patient's MediSync Patient ID
    (format: MED-XXXXXX).

    Validations:
    - The patient_code must correspond to an existing, active user.
    - That user must have role = 'patient' (cannot link caregiver to caregiver).
    - The caregiver cannot link to themselves.
    - Duplicate links are silently ignored (ON CONFLICT DO NOTHING).
    """
    pool = get_pool()

    patient_code = body.patientCode.strip().upper()
    if not patient_code:
        raise HTTPException(status_code=400, detail='Patient ID is required.')

    # Resolve public patient_code → internal user record
    patient = await pool.fetchrow(
        "SELECT * FROM users WHERE patient_code = %s AND is_active = TRUE LIMIT 1",
        patient_code,
    )
    if not patient:
        raise HTTPException(
            status_code=404,
            detail='Patient not found. Please check the Patient ID and try again.',
        )

    # Ensure the resolved user is actually a patient
    if patient['role'] != 'patient':
        raise HTTPException(
            status_code=400,
            detail='The provided ID does not belong to a patient account.',
        )

    # Prevent self-linking
    if str(patient['id']) == user['id']:
        raise HTTPException(status_code=400, detail='You cannot link to your own account.')

    # Check if already linked
    existing = await pool.fetchrow(
        'SELECT 1 FROM caregiver_patient_links WHERE caregiver_id = %s AND patient_id = %s',
        user['id'], str(patient['id']),
    )
    if existing:
        raise HTTPException(
            status_code=409,
            detail='This patient is already linked to your account.',
        )

    # Create the relationship using the real internal UUID
    await pool.execute(
        'INSERT INTO caregiver_patient_links (caregiver_id, patient_id) VALUES (%s, %s)',
        user['id'], str(patient['id']),
    )
    return {'success': True, 'message': f"Successfully linked to patient: {patient['name']}"}


@router.delete('/unlink/{patient_id}')
async def unlink_patient(patient_id: str, user: dict = Depends(get_current_user)):
    pool = get_pool()
    await pool.execute(
        'DELETE FROM caregiver_patient_links WHERE caregiver_id = %s AND patient_id = %s',
        user['id'], patient_id,
    )
    return {'success': True, 'message': 'Unlinked successfully'}


@router.post('/patients/create', status_code=201)
async def create_patient(body: CreatePatientBody, user: dict = Depends(get_current_user)):
    """
    Create a brand-new patient record and automatically link them to this caregiver.
    Patients created here have NO Firebase account (firebase_uid = NULL) —
    they are managed entirely by caregivers through the app.
    A unique MED-XXXXXX patient_code is auto-generated.
    """
    pool = get_pool()

    # Generate a unique patient_code (MED-XXXXXX)
    import random, string
    for _ in range(10):
        suffix = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
        code = f"MED-{suffix}"
        existing = await pool.fetchrow("SELECT 1 FROM users WHERE patient_code = %s", code)
        if not existing:
            break
    else:
        raise HTTPException(status_code=500, detail="Failed to generate a unique patient code.")

    # Use provided email or a placeholder — firebase_uid is NULL (no app login for patients)
    email = body.email or f"patient_{code.lower().replace('-', '_')}@medisync.local"

    # Create the patient row
    # firebase_uid = NULL  (schema now allows NULL for patient rows)
    # created_by   = caregiver UUID who created this patient
    new_patient = await pool.fetchrow(
        """INSERT INTO users
             (firebase_uid, name, email, role, phone_number, patient_code, created_by)
           VALUES (NULL, %s, %s, 'patient', %s, %s, %s)
           RETURNING *""",
        body.name.strip(), email,
        body.phoneNumber, code, user['id'],
    )

    patient_id = str(new_patient['id'])

    # Auto-link to this caregiver
    await pool.execute(
        'INSERT INTO caregiver_patient_links (caregiver_id, patient_id) '
        'VALUES (%s, %s) ON CONFLICT DO NOTHING',
        user['id'], patient_id,
    )

    return {
        'success': True,
        'message': f"Patient '{body.name}' created and linked successfully.",
        'data': {k: v for k, v in row_to_user(new_patient).items() if k != 'fcmToken'},
    }


@router.get('/patients/{patient_id}/medicines')
async def get_patient_medicines(patient_id: str, user: dict = Depends(get_current_user)):
    if not await _check_access(user['id'], patient_id):
        raise HTTPException(
            status_code=403,
            detail='You are not authorized to access this patient\'s data.',
        )
    pool = get_pool()
    rows = await pool.fetch(
        'SELECT * FROM medicines WHERE user_id = %s AND is_active = TRUE ORDER BY created_at DESC', patient_id
    )
    return {'success': True, 'data': [_row_to_med(r) for r in rows]}


@router.get('/patients/{patient_id}/doses')
async def get_patient_doses(
    patient_id: str,
    from_date: Optional[str] = Query(None, alias='from'),
    to_date:   Optional[str] = Query(None, alias='to'),
    user: dict = Depends(get_current_user),
):
    if not await _check_access(user['id'], patient_id):
        raise HTTPException(
            status_code=403,
            detail='You are not authorized to access this patient\'s data.',
        )
    pool   = get_pool()
    conds  = ['user_id = %s']
    values = [patient_id]
    if from_date: conds.append('scheduled_time >= %s'); values.append(datetime.fromisoformat(from_date))
    if to_date:   conds.append('scheduled_time <= %s'); values.append(datetime.fromisoformat(to_date))
    rows = await pool.fetch(
        f"SELECT * FROM dose_records WHERE {' AND '.join(conds)} ORDER BY scheduled_time DESC LIMIT 50", *values
    )
    return {'success': True, 'data': [_row_to_dose(r) for r in rows]}


@router.post('/patients/{patient_id}/medicines', status_code=201)
async def add_medicine_for_patient(patient_id: str, body: AddMedBody, user: dict = Depends(get_current_user)):
    if not await _check_access(user['id'], patient_id):
        raise HTTPException(
            status_code=403,
            detail='You are not authorized to access this patient\'s data.',
        )
    pool = get_pool()
    from routers.medicines import check_compartment_conflict
    conflict_name = await check_compartment_conflict(pool, patient_id, body.compartmentNumber, body.name)
    if conflict_name:
        raise HTTPException(status_code=400, detail=f"Compartment {body.compartmentNumber} is already used by {conflict_name}.")
        
    row  = await pool.fetchrow(
        """INSERT INTO medicines
             (user_id, name, dosage, quantity, reminder_times, start_date,
              end_date, expiry_date, compartment_number, food_instruction, notes, color)
           VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING *""",
        patient_id, body.name, body.dosage, body.quantity, body.reminderTimes,
        body.startDate, body.endDate, body.expiryDate,
        body.compartmentNumber, body.foodInstruction, body.notes, body.color,
    )
    medicine = _row_to_med(row)
    patient  = await pool.fetchrow('SELECT fcm_token FROM users WHERE id = %s LIMIT 1', patient_id)
    if patient and patient['fcm_token']:
        await send_fcm_notification(patient['fcm_token'], '🔔 Schedule Updated',
                                    f"Your caregiver added {medicine['name']} to your schedule.",
                                    {'type': 'scheduleUpdate', 'medicineId': medicine['id']})
    return {'success': True, 'data': medicine}


# Re-using from medicines router
from routers.medicines import UpdateMedicineBody, check_compartment_conflict

@router.put('/patients/{patient_id}/medicines/{med_id}')
async def update_patient_medicine(patient_id: str, med_id: str, body: UpdateMedicineBody, user: dict = Depends(get_current_user)):
    if not await _check_access(user['id'], patient_id):
        raise HTTPException(status_code=403, detail='Not authorized.')
    
    pool = get_pool()
    existing_med = await pool.fetchrow('SELECT * FROM medicines WHERE id = %s AND user_id = %s', med_id, patient_id)
    if not existing_med:
        raise HTTPException(status_code=404, detail='Medicine not found')
        
    target_compartment = body.compartmentNumber if body.compartmentNumber is not None else existing_med['compartment_number']
    target_active = body.isActive if body.isActive is not None else existing_med['is_active']
    target_name = body.name if body.name is not None else existing_med['name']
    
    if target_active:
        conflict_name = await check_compartment_conflict(pool, patient_id, target_compartment, target_name, med_id)
        if conflict_name:
            raise HTTPException(status_code=400, detail=f"Compartment {target_compartment} is already used by {conflict_name}.")

    mapping = {
        'name': 'name', 'dosage': 'dosage', 'quantity': 'quantity',
        'reminderTimes': 'reminder_times', 'startDate': 'start_date',
        'endDate': 'end_date', 'expiryDate': 'expiry_date',
        'compartmentNumber': 'compartment_number', 'foodInstruction': 'food_instruction',
        'notes': 'notes', 'isActive': 'is_active', 'color': 'color',
    }
    data   = body.model_dump(exclude_none=True)
    fields, values = [], []
    for js_key, sql_col in mapping.items():
        if js_key in data:
            fields.append(f'{sql_col} = %s'); values.append(data[js_key])
    if not fields:
        raise HTTPException(status_code=400, detail='No fields to update')
    values += [med_id, patient_id]
    
    row = await pool.fetchrow(
        f"UPDATE medicines SET {', '.join(fields)} WHERE id = %s AND user_id = %s RETURNING *", *values
    )
    if not row:
        raise HTTPException(status_code=404, detail='Medicine not found')
        
    medicine = _row_to_med(row)
    patient_row  = await pool.fetchrow('SELECT fcm_token FROM users WHERE id = %s LIMIT 1', patient_id)
    if patient_row and patient_row['fcm_token']:
        await send_fcm_notification(patient_row['fcm_token'], '🔔 Schedule Updated',
                                    f"Your caregiver updated {medicine['name']}.",
                                    {'type': 'scheduleUpdate', 'medicineId': medicine['id']})
    return {'success': True, 'data': medicine}


@router.delete('/patients/{patient_id}/medicines/{med_id}')
async def delete_patient_medicine(patient_id: str, med_id: str, user: dict = Depends(get_current_user)):
    if not await _check_access(user['id'], patient_id):
        raise HTTPException(status_code=403, detail='Not authorized.')
    pool = get_pool()
    row  = await pool.fetchrow(
        'DELETE FROM medicines WHERE id = %s AND user_id = %s RETURNING *', med_id, patient_id
    )
    if not row:
        raise HTTPException(status_code=404, detail='Medicine not found')
        
    await pool.execute(
        "DELETE FROM dose_records WHERE medicine_id = %s AND user_id = %s AND status = 'pending' AND scheduled_time >= NOW()",
        med_id, patient_id,
    )
    return {'success': True, 'message': 'Medicine deleted successfully'}
