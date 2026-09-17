# backend/routers/dispenser.py — psycopg3 (%s placeholders)
import json
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timezone
from db.database import get_pool
from middleware.auth import get_current_user
from config.firebase import send_fcm_multicast
from socket_manager import sio

router = APIRouter(prefix='/api/v1/dispenser', tags=['dispenser'])


def row_to_dispenser(row) -> dict:
    if not row:
        return None
    r = dict(row)
    return {
        'id':                 str(r['id']),
        'deviceId':           r['device_id'],
        'userId':             str(r['user_id']),
        'isOnline':           r['is_online'],
        'batteryLevel':       r['battery_level'],
        'wifiSignalStrength': r['wifi_signal_strength'],
        'firmwareVersion':    r['firmware_version'],
        'totalDispenses':     r['total_dispenses'],
        'isEmergencyMode':    r['is_emergency_mode'],
        'lastSeen':           r['last_seen'].isoformat() if r['last_seen'] else None,
        'compartments':       r['compartments'],
        'pendingDispense':    r['pending_dispense'],
        'createdAt':          r['created_at'].isoformat() if r.get('created_at') else None,
    }


class RegisterBody(BaseModel):
    deviceId: str

class DispenseBody(BaseModel):
    compartmentNumber: int
    triggeredBy:       str = 'patient'

class EmergencyBody(BaseModel):
    compartmentNumber: Optional[int] = 1

class HeartbeatBody(BaseModel):
    deviceId:           str
    batteryLevel:       Optional[int]  = None
    wifiSignalStrength: Optional[int]  = None
    firmwareVersion:    Optional[str]  = None
    compartments:       Optional[List] = None
    dispensed:          Optional[bool] = False


@router.get('/status')
async def get_status(user: dict = Depends(get_current_user)):
    pool = get_pool()
    row  = await pool.fetchrow('SELECT * FROM dispensers WHERE user_id = %s LIMIT 1', user['id'])
    if not row:
        raise HTTPException(status_code=404, detail='No dispenser linked to this account')
    stale = (not row['last_seen'] or
             (datetime.now(timezone.utc) - row['last_seen'].replace(tzinfo=timezone.utc)).total_seconds() > 120)
    if stale and row['is_online']:
        row = await pool.fetchrow(
            'UPDATE dispensers SET is_online = FALSE WHERE id = %s RETURNING *', str(row['id'])
        )
    return {'success': True, 'data': row_to_dispenser(row)}


@router.post('/register', status_code=201)
async def register_device(body: RegisterBody, user: dict = Depends(get_current_user)):
    pool     = get_pool()
    existing = await pool.fetchrow('SELECT * FROM dispensers WHERE device_id = %s', body.deviceId)
    if existing and str(existing['user_id']) != user['id']:
        raise HTTPException(status_code=409, detail='Device already linked to another account')
    row = await pool.fetchrow(
        """INSERT INTO dispensers (device_id, user_id)
           VALUES (%s, %s)
           ON CONFLICT (device_id) DO UPDATE SET user_id = EXCLUDED.user_id
           RETURNING *""",
        body.deviceId, user['id'],
    )
    await pool.execute('UPDATE users SET device_id = %s WHERE id = %s', body.deviceId, user['id'])
    return {'success': True, 'data': row_to_dispenser(row)}


@router.post('/dispense')
async def manual_dispense(body: DispenseBody, user: dict = Depends(get_current_user)):
    pool    = get_pool()
    pending = {
        'compartmentNumber': body.compartmentNumber,
        'triggeredAt':       datetime.utcnow().isoformat(),
        'triggeredBy':       body.triggeredBy,
        'isAcknowledged':    False,
    }
    row = await pool.fetchrow(
        'UPDATE dispensers SET pending_dispense = %s WHERE user_id = %s RETURNING *',
        json.dumps(pending), user['id'],
    )
    if not row:
        raise HTTPException(status_code=404, detail='Dispenser not found')
    await sio.emit('dispense:command', {
        'compartmentNumber': body.compartmentNumber,
        'triggeredBy':       body.triggeredBy,
        'timestamp':         pending['triggeredAt'],
    }, room=f"device:{row['device_id']}")
    return {'success': True, 'message': f'Dispense command sent to compartment {body.compartmentNumber}', 'data': row_to_dispenser(row)}


@router.post('/emergency')
async def emergency_dispense(body: EmergencyBody, user: dict = Depends(get_current_user)):
    pool = get_pool()
    disp = await pool.fetchrow('SELECT * FROM dispensers WHERE user_id = %s LIMIT 1', user['id'])
    if not disp:
        raise HTTPException(status_code=404, detail='Dispenser not found')
    pending = {
        'compartmentNumber': body.compartmentNumber,
        'triggeredAt':       datetime.utcnow().isoformat(),
        'triggeredBy':       'emergency',
        'isAcknowledged':    False,
    }
    await pool.execute(
        'UPDATE dispensers SET is_emergency_mode = TRUE, pending_dispense = %s WHERE id = %s',
        json.dumps(pending), str(disp['id']),
    )
    await sio.emit('dispense:emergency', {'compartmentNumber': body.compartmentNumber},
                   room=f"device:{disp['device_id']}")
    caregivers = await pool.fetch(
        """SELECT u.fcm_token FROM caregiver_patient_links cpl
           JOIN users u ON u.id = cpl.caregiver_id
           WHERE cpl.patient_id = %s AND u.fcm_token IS NOT NULL""",
        user['id'],
    )
    tokens = [c['fcm_token'] for c in caregivers]
    if tokens:
        await send_fcm_multicast(tokens, '🚨 Emergency SOS',
                                 f"{user['name']} triggered an emergency dispense!",
                                 {'patientId': user['id'], 'type': 'emergency'})
    return {'success': True, 'message': 'Emergency dispense triggered'}


@router.post('/heartbeat')
async def heartbeat(body: HeartbeatBody):
    pool    = get_pool()
    updates = ['is_online = TRUE', 'last_seen = NOW()']
    values  = []
    if body.batteryLevel        is not None: updates.append('battery_level = %s');        values.append(body.batteryLevel)
    if body.wifiSignalStrength  is not None: updates.append('wifi_signal_strength = %s'); values.append(body.wifiSignalStrength)
    if body.firmwareVersion     is not None: updates.append('firmware_version = %s');     values.append(body.firmwareVersion)
    if body.compartments        is not None: updates.append('compartments = %s');         values.append(json.dumps(body.compartments))
    if body.dispensed:
        updates.append('pending_dispense = NULL')
        updates.append('total_dispenses = total_dispenses + 1')
    values.append(body.deviceId)
    row = await pool.fetchrow(
        f"UPDATE dispensers SET {', '.join(updates)} WHERE device_id = %s RETURNING *", *values
    )
    if not row:
        raise HTTPException(status_code=404, detail='Device not found')
    return {'success': True, 'data': row['pending_dispense']}
