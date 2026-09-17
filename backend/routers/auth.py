# backend/routers/auth.py — psycopg3 (%s placeholders)
import random
import string
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import Optional
from db.database import get_pool
from middleware.auth import get_current_user, row_to_user

router = APIRouter(prefix='/api/v1/auth', tags=['auth'])


def _generate_patient_code() -> str:
    """Generate a unique MED-XXXXXX patient code (6 uppercase alphanumeric chars)."""
    chars = string.ascii_uppercase + string.digits
    suffix = ''.join(random.choices(chars, k=6))
    return f"MED-{suffix}"


async def _ensure_patient_code(pool, user_id: str) -> str:
    """
    Assign a patient_code to a user who doesn't have one yet.
    Retries on the rare chance of a collision (UNIQUE constraint violation).
    """
    for _ in range(10):  # max 10 attempts
        code = _generate_patient_code()
        try:
            await pool.execute(
                "UPDATE users SET patient_code = %s WHERE id = %s AND patient_code IS NULL",
                code, user_id,
            )
            return code
        except Exception:
            # Collision — try again
            continue
    raise RuntimeError("Failed to generate a unique patient_code after 10 attempts.")


class SyncProfileBody(BaseModel):
    name:     Optional[str] = None
    role:     Optional[str] = None
    photoUrl: Optional[str] = None
    fcmToken: Optional[str] = None


class UpdateProfileBody(BaseModel):
    name:                   Optional[str]  = None
    phoneNumber:            Optional[str]  = None
    emergencyContactName:   Optional[str]  = None
    emergencyContactPhone:  Optional[str]  = None
    deviceId:               Optional[str]  = None
    notificationsEnabled:   Optional[bool] = None
    biometricEnabled:       Optional[bool] = None
    themeMode:              Optional[str]  = None
    soundEnabled:           Optional[bool] = None
    vibrationEnabled:       Optional[bool] = None
    fcmToken:               Optional[str]  = None


@router.post('/sync')
async def sync_profile(body: SyncProfileBody, user: dict = Depends(get_current_user)):
    pool   = get_pool()
    fields, values = [], []
    # Default to 'caregiver' if no role provided (app is caregiver-only)
    role_to_set = body.role or 'caregiver'
    if body.name:     fields.append('name = %s');      values.append(body.name)
    fields.append('role = %s'); values.append(role_to_set)
    if body.photoUrl: fields.append('photo_url = %s'); values.append(body.photoUrl)
    if body.fcmToken: fields.append('fcm_token = %s'); values.append(body.fcmToken)

    if fields:
        values.append(user['id'])
        row = await pool.fetchrow(
            f"UPDATE users SET {', '.join(fields)} WHERE id = %s RETURNING *", *values
        )
        user = row_to_user(row)

    # Only assign patient_code for actual patient rows (not caregivers)
    if user.get('role') == 'patient' and not user.get('patientCode'):
        code = await _ensure_patient_code(pool, user['id'])
        user = dict(user)
        user['patientCode'] = code

    return {'success': True, 'data': user}


@router.get('/me')
async def get_me(user: dict = Depends(get_current_user)):
    pool = get_pool()
    # Only backfill patient_code for patient role users
    if user.get('role') == 'patient' and not user.get('patientCode'):
        code = await _ensure_patient_code(pool, user['id'])
        user = dict(user)
        user['patientCode'] = code
    return {'success': True, 'data': {k: v for k, v in user.items() if k != 'fcmToken'}}


@router.put('/profile')
async def update_profile(body: UpdateProfileBody, user: dict = Depends(get_current_user)):
    pool    = get_pool()
    mapping = {
        'name': 'name', 'phoneNumber': 'phone_number',
        'emergencyContactName': 'emergency_contact_name',
        'emergencyContactPhone': 'emergency_contact_phone',
        'deviceId': 'device_id', 'notificationsEnabled': 'notifications_enabled',
        'biometricEnabled': 'biometric_enabled', 'themeMode': 'theme_mode',
        'soundEnabled': 'sound_enabled', 'vibrationEnabled': 'vibration_enabled',
        'fcmToken': 'fcm_token',
    }
    data   = body.model_dump(exclude_none=True)
    fields, values = [], []
    for js_key, sql_col in mapping.items():
        if js_key in data:
            fields.append(f'{sql_col} = %s'); values.append(data[js_key])
    if not fields:
        return {'success': True, 'data': user}
    values.append(user['id'])
    row = await pool.fetchrow(
        f"UPDATE users SET {', '.join(fields)} WHERE id = %s RETURNING *", *values
    )
    return {'success': True, 'data': row_to_user(row)}


@router.delete('/account')
async def delete_account(user: dict = Depends(get_current_user)):
    pool = get_pool()
    await pool.execute('UPDATE users SET is_active = FALSE WHERE id = %s', user['id'])
    return {'success': True, 'message': 'Account deactivated successfully'}
