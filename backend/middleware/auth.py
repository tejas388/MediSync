# backend/middleware/auth.py
# MediSync - Firebase token verification FastAPI dependency
# All app users authenticate as caregivers. Patients are DB-only records.

import uuid
from typing import Optional
from fastapi import Depends, HTTPException, Header
from db.database import get_pool
from config.firebase import verify_firebase_token


def _serialize(value):
    if value is None:
        return None
    if isinstance(value, uuid.UUID):
        return str(value)
    if hasattr(value, 'isoformat'):
        return value.isoformat()
    return value


def row_to_user(row) -> dict:
    """Convert a DB row to a caregiver/patient dict for API responses."""
    if not row:
        return None
    r = dict(row)
    return {
        'id':                     str(r['id']),
        # firebase_uid is NULL for caregiver-created patient records
        'firebaseUid':            r.get('firebase_uid'),
        'name':                   r['name'],
        'email':                  r['email'],
        'role':                   r['role'],
        'photoUrl':               r.get('photo_url'),
        'phoneNumber':            r.get('phone_number'),
        'deviceId':               r.get('device_id'),
        'emergencyContactName':   r.get('emergency_contact_name'),
        'emergencyContactPhone':  r.get('emergency_contact_phone'),
        'fcmToken':               r.get('fcm_token'),
        'notificationsEnabled':   r.get('notifications_enabled', True),
        'biometricEnabled':       r.get('biometric_enabled', False),
        'themeMode':              r.get('theme_mode', 'system'),
        'soundEnabled':           r.get('sound_enabled', True),
        'vibrationEnabled':       r.get('vibration_enabled', True),
        'isActive':               r.get('is_active', True),
        # patientCode: MED-XXXXXX, only set for role='patient' rows
        'patientCode':            r.get('patient_code'),
        # createdBy: UUID of the caregiver who created this patient record
        'createdBy':              str(r['created_by']) if r.get('created_by') else None,
        'createdAt':              _serialize(r.get('created_at')),
        'updatedAt':              _serialize(r.get('updated_at')),
    }


async def get_current_user(authorization: Optional[str] = Header(None)) -> dict:
    """
    Verify Firebase Bearer token and return the caregiver's DB row.
    Only caregivers can authenticate — patient rows have no Firebase account.
    """
    if not authorization or not authorization.startswith('Bearer '):
        raise HTTPException(status_code=401, detail='No authentication token provided')

    id_token = authorization.split('Bearer ')[1]

    try:
        decoded = await verify_firebase_token(id_token)
    except Exception:
        raise HTTPException(status_code=401, detail='Invalid or expired authentication token')

    pool = get_pool()
    row  = await pool.fetchrow(
        'SELECT * FROM users WHERE firebase_uid = %s AND is_active = TRUE',
        decoded['uid'],
    )

    if not row:
        # First login — auto-create caregiver account
        name = decoded.get('name') or decoded.get('email', 'User').split('@')[0]
        row  = await pool.fetchrow(
            """INSERT INTO users (firebase_uid, email, name, role, photo_url)
               VALUES (%s, %s, %s, 'caregiver', %s) RETURNING *""",
            decoded['uid'],
            decoded.get('email', ''),
            name,
            decoded.get('picture'),
        )

    return row_to_user(row)


def require_role(*roles):
    async def _check(user: dict = Depends(get_current_user)):
        if user.get('role') not in roles:
            raise HTTPException(
                status_code=403,
                detail=f"Access denied — requires role: {' or '.join(roles)}",
            )
        return user
    return _check
