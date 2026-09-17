# backend/routers/medicines.py — psycopg3 (%s placeholders)
import uuid
from fastapi import APIRouter, Depends, Query, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from datetime import date
from db.database import get_pool
from middleware.auth import get_current_user
from services.notification import create_notification

router = APIRouter(prefix='/api/v1/medicines', tags=['medicines'])


def row_to_med(row) -> dict:
    if not row:
        return None
    r = dict(row)
    expiry = r.get('expiry_date')
    today  = date.today()
    is_expired        = (expiry < today)              if expiry else False
    is_expiring_soon  = (0 <= (expiry - today).days <= 30) if expiry and not is_expired else False
    return {
        'id':                str(r['id']),
        'userId':            str(r['user_id']),
        'name':              r['name'],
        'dosage':            r['dosage'],
        'quantity':          r['quantity'],
        'reminderTimes':     r['reminder_times'],
        'startDate':         r['start_date'].isoformat() if r['start_date'] else None,
        'endDate':           r['end_date'].isoformat()   if r['end_date']   else None,
        'expiryDate':        expiry.isoformat()           if expiry          else None,
        'compartmentNumber': r['compartment_number'],
        'foodInstruction':   r['food_instruction'],
        'notes':             r['notes'],
        'isActive':          r['is_active'],
        'color':             r['color'],
        'isLowStock':        r['quantity'] < 5,
        'isExpired':         is_expired,
        'isExpiringSoon':    is_expiring_soon,
        'createdAt':         r['created_at'].isoformat() if r.get('created_at') else None,
        'updatedAt':         r['updated_at'].isoformat() if r.get('updated_at') else None,
    }

async def check_compartment_conflict(pool, user_id: str, compartment_number: int, medicine_name: str, exclude_med_id: Optional[str] = None):
    link = await pool.fetchrow('SELECT caregiver_id FROM caregiver_patient_links WHERE patient_id = %s LIMIT 1', user_id)
    owner_id = link['caregiver_id'] if link else user_id

    query = """
        SELECT id, name FROM medicines 
        WHERE compartment_number = %s AND is_active = TRUE 
        AND (user_id = %s OR user_id IN (SELECT patient_id FROM caregiver_patient_links WHERE caregiver_id = %s))
    """
    params = [compartment_number, owner_id, owner_id]
    if exclude_med_id:
        query += " AND id != %s"
        params.append(exclude_med_id)
        
    conflicts = await pool.fetch(query, *params)
    for c in conflicts:
        if c['name'].lower().strip() != medicine_name.lower().strip():
            return c['name']
    return None


class AddMedicineBody(BaseModel):
    name:              str
    dosage:            str
    quantity:          int               = 0
    reminderTimes:     List[str]         = []
    startDate:         date
    endDate:           Optional[date]    = None
    expiryDate:        Optional[date]    = None
    compartmentNumber: int
    foodInstruction:   str               = 'No restriction'
    notes:             Optional[str]     = None
    color:             str               = '#0A7EA4'


class UpdateMedicineBody(BaseModel):
    name:              Optional[str]       = None
    dosage:            Optional[str]       = None
    quantity:          Optional[int]       = None
    reminderTimes:     Optional[List[str]] = None
    startDate:         Optional[date]      = None
    endDate:           Optional[date]      = None
    expiryDate:        Optional[date]      = None
    compartmentNumber: Optional[int]       = None
    foodInstruction:   Optional[str]       = None
    notes:             Optional[str]       = None
    isActive:          Optional[bool]      = None
    color:             Optional[str]       = None


class StockBody(BaseModel):
    quantity: int


@router.get('/')
async def get_medicines(
    active: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    user: dict = Depends(get_current_user),
):
    pool   = get_pool()
    conds  = ['user_id = %s']
    values = [user['id']]
    if active is not None:
        conds.append('is_active = %s'); values.append(active == 'true')
    if search:
        conds.append('name ILIKE %s'); values.append(f'%{search}%')
    rows = await pool.fetch(
        f"SELECT * FROM medicines WHERE {' AND '.join(conds)} ORDER BY created_at DESC", *values
    )
    data = [row_to_med(r) for r in rows]
    return {'success': True, 'count': len(data), 'data': data}


@router.get('/shared-compartments')
async def get_shared_compartments(user: dict = Depends(get_current_user)):
    pool = get_pool()
    link = await pool.fetchrow('SELECT caregiver_id FROM caregiver_patient_links WHERE patient_id = %s LIMIT 1', user['id'])
    owner_id = link['caregiver_id'] if link else user['id']
    
    query = """
        SELECT compartment_number, name FROM medicines 
        WHERE is_active = TRUE 
        AND (user_id = %s OR user_id IN (SELECT patient_id FROM caregiver_patient_links WHERE caregiver_id = %s))
    """
    rows = await pool.fetch(query, owner_id, owner_id)
    result = {r['compartment_number']: r['name'] for r in rows}
    return {'success': True, 'data': result}


@router.get('/{med_id}')
async def get_medicine(med_id: str, user: dict = Depends(get_current_user)):
    pool = get_pool()
    row  = await pool.fetchrow(
        'SELECT * FROM medicines WHERE id = %s AND user_id = %s', med_id, user['id']
    )
    if not row:
        raise HTTPException(status_code=404, detail='Medicine not found')
    return {'success': True, 'data': row_to_med(row)}


@router.post('/', status_code=201)
async def add_medicine(body: AddMedicineBody, user: dict = Depends(get_current_user)):
    pool = get_pool()
    
    conflict_name = await check_compartment_conflict(pool, user['id'], body.compartmentNumber, body.name)
    if conflict_name:
        raise HTTPException(status_code=400, detail=f"Compartment {body.compartmentNumber} is already used by {conflict_name}.")
        
    row  = await pool.fetchrow(
        """INSERT INTO medicines
             (user_id, name, dosage, quantity, reminder_times, start_date,
              end_date, expiry_date, compartment_number, food_instruction, notes, color)
           VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING *""",
        user['id'], body.name, body.dosage, body.quantity,
        body.reminderTimes, body.startDate, body.endDate, body.expiryDate,
        body.compartmentNumber, body.foodInstruction, body.notes, body.color,
    )
    return {'success': True, 'data': row_to_med(row)}


@router.put('/{med_id}')
async def update_medicine(med_id: str, body: UpdateMedicineBody, user: dict = Depends(get_current_user)):
    pool    = get_pool()
    
    existing_med = await pool.fetchrow('SELECT * FROM medicines WHERE id = %s AND user_id = %s', med_id, user['id'])
    if not existing_med:
        raise HTTPException(status_code=404, detail='Medicine not found')
        
    target_compartment = body.compartmentNumber if body.compartmentNumber is not None else existing_med['compartment_number']
    target_active = body.isActive if body.isActive is not None else existing_med['is_active']
    target_name = body.name if body.name is not None else existing_med['name']
    
    if target_active:
        conflict_name = await check_compartment_conflict(pool, user['id'], target_compartment, target_name, med_id)
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
    values += [med_id, user['id']]
    row = await pool.fetchrow(
        f"UPDATE medicines SET {', '.join(fields)} WHERE id = %s AND user_id = %s RETURNING *", *values
    )
    if not row:
        raise HTTPException(status_code=404, detail='Medicine not found')
    return {'success': True, 'data': row_to_med(row)}


@router.delete('/{med_id}')
async def delete_medicine(med_id: str, user: dict = Depends(get_current_user)):
    pool = get_pool()
    row  = await pool.fetchrow(
        'DELETE FROM medicines WHERE id = %s AND user_id = %s RETURNING *', med_id, user['id']
    )
    if not row:
        raise HTTPException(status_code=404, detail='Medicine not found')
    await pool.execute(
        "DELETE FROM dose_records WHERE medicine_id = %s AND user_id = %s AND status = 'pending' AND scheduled_time >= NOW()",
        med_id, user['id'],
    )
    return {'success': True, 'message': 'Medicine deleted successfully'}


@router.patch('/{med_id}/stock')
async def update_stock(med_id: str, body: StockBody, user: dict = Depends(get_current_user)):
    if body.quantity < 0:
        raise HTTPException(status_code=400, detail='Valid quantity required')
    pool = get_pool()
    row  = await pool.fetchrow(
        'UPDATE medicines SET quantity = %s WHERE id = %s AND user_id = %s RETURNING *',
        body.quantity, med_id, user['id'],
    )
    if not row:
        raise HTTPException(status_code=404, detail='Medicine not found')
    med = row_to_med(row)
    if med['quantity'] < 5:
        await create_notification(user['id'], {
            'title': '📦 Low Stock Alert',
            'body':  f"{med['name']} has only {med['quantity']} tablet(s) left. Please refill.",
            'type':  'lowStock', 'medicineId': med['id'], 'medicineName': med['name'],
        }, user.get('fcmToken'))
    return {'success': True, 'data': med}


@router.patch('/{med_id}/toggle')
async def toggle_active(med_id: str, user: dict = Depends(get_current_user)):
    pool = get_pool()
    
    existing_med = await pool.fetchrow('SELECT name, is_active, compartment_number FROM medicines WHERE id = %s AND user_id = %s', med_id, user['id'])
    if not existing_med:
        raise HTTPException(status_code=404, detail='Medicine not found')
        
    if not existing_med['is_active']:
        conflict_name = await check_compartment_conflict(pool, user['id'], existing_med['compartment_number'], existing_med['name'], med_id)
        if conflict_name:
            raise HTTPException(status_code=400, detail=f"Cannot activate: Compartment {existing_med['compartment_number']} is already used by {conflict_name}.")

    row  = await pool.fetchrow(
        'UPDATE medicines SET is_active = NOT is_active WHERE id = %s AND user_id = %s RETURNING *',
        med_id, user['id'],
    )
    if not row:
        raise HTTPException(status_code=404, detail='Medicine not found')
    return {'success': True, 'data': row_to_med(row)}
