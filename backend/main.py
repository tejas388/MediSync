# backend/main.py
# MediSync - FastAPI + Socket.IO entry point (replaces server.js)
# Run: uvicorn main:app --host 0.0.0.0 --port 5001 --reload

import os
import json
from contextlib import asynccontextmanager
from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

import socketio

from db.database import init_pool, close_pool, get_pool
from config.firebase import init_firebase
from socket_manager import sio, connected_devices
from services.scheduler import setup_scheduler, stop_scheduler

# ── Routers ───────────────────────────────────────────────────────────────────
from routers.auth          import router as auth_router
from routers.medicines     import router as medicine_router
from routers.doses         import router as dose_router
from routers.dispenser     import router as dispenser_router
from routers.caregiver     import router as caregiver_router
from routers.analytics     import router as analytics_router
from routers.reports       import router as reports_router
from routers.notifications import router as notifications_router


# ── Lifespan (startup / shutdown) ────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── Startup ──────────────────────────────────────────────────────────────
    await init_pool()
    init_firebase()
    setup_scheduler(sio)
    print(f"\n[*] MediSync API Server running on port {os.getenv('PORT', 5000)}")
    print(f"[i] Environment: {os.getenv('NODE_ENV', 'development')}")
    print(f"[i] Database:    PostgreSQL")
    print(f"[i] Runtime:     Python / FastAPI")
    print(f"[i] Health:      http://localhost:{os.getenv('PORT', 5000)}/health\n")
    yield
    # ── Shutdown ─────────────────────────────────────────────────────────────
    stop_scheduler()
    await close_pool()


# ── FastAPI app ───────────────────────────────────────────────────────────────
fastapi_app = FastAPI(
    title='MediSync API',
    version='1.0.0',
    description='Smart Medicine Dispenser REST API — Python/FastAPI + PostgreSQL',
    lifespan=lifespan,
    docs_url='/docs',
    redoc_url='/redoc',
)

# CORS
# CORS
fastapi_app.add_middleware(
    CORSMiddleware,
    allow_origins=[],
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Health check ──────────────────────────────────────────────────────────────
@fastapi_app.get('/health')
async def health():
    try:
        pool = get_pool()
        db_time = await pool.fetchval('SELECT NOW()')
        return {
            'success':   True,
            'message':   'MediSync API is running 🚀',
            'timestamp': db_time.isoformat(),
            'database':  'PostgreSQL',
            'runtime':   'Python / FastAPI',
            'version':   '1.0.0',
            'env':       os.getenv('NODE_ENV', 'development'),
        }
    except Exception as e:
        return JSONResponse(status_code=503, content={'success': False, 'message': str(e)})

# ── Register routers ──────────────────────────────────────────────────────────
fastapi_app.include_router(auth_router)
fastapi_app.include_router(medicine_router)
fastapi_app.include_router(dose_router)
fastapi_app.include_router(dispenser_router)
fastapi_app.include_router(caregiver_router)
fastapi_app.include_router(analytics_router)
fastapi_app.include_router(reports_router)
fastapi_app.include_router(notifications_router)

from starlette.exceptions import HTTPException as StarletteHTTPException

# ── 404 handler ───────────────────────────────────────────────────────────────
@fastapi_app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    if exc.status_code == 404 and exc.detail == "Not Found":
        return JSONResponse(status_code=404, content={
            'success': False,
            'message': f'Route {request.method} {request.url.path} not found',
        })
    return JSONResponse(status_code=exc.status_code, content={
        'success': False,
        'message': exc.detail,
    })

# ── Global error handler ──────────────────────────────────────────────────────
@fastapi_app.exception_handler(Exception)
async def global_error(request: Request, exc: Exception):
    return JSONResponse(status_code=500, content={
        'success': False, 'message': str(exc),
    })


# ═══════════════════════════════════════════════════════════════════════════════
# Socket.IO — Real-time ESP32 Communication
# ═══════════════════════════════════════════════════════════════════════════════

@sio.event
async def connect(sid, environ):
    print(f'[Socket.IO] Client connected: {sid}')


@sio.event
async def disconnect(sid):
    for device_id, s in list(connected_devices.items()):
        if s == sid:
            del connected_devices[device_id]
            print(f'[Socket.IO] ESP32 disconnected: {device_id}')
            break
    print(f'[Socket.IO] Client disconnected: {sid}')


# ESP32 device registration
@sio.on('device:register')
async def on_device_register(sid, data):
    device_id = data.get('deviceId')
    token     = data.get('token')
    if token != os.getenv('ESP32_AUTH_TOKEN'):
        await sio.emit('device:error', {'message': 'Invalid device token'}, to=sid)
        return
    connected_devices[device_id] = sid
    await sio.enter_room(sid, f'device:{device_id}')
    print(f'[Socket.IO] ESP32 registered: {device_id}')
    await sio.emit('device:registered', {'message': 'Device registered successfully'}, to=sid)


# ESP32 status heartbeat — update dispenser row in PostgreSQL
@sio.on('device:status')
async def on_device_status(sid, data):
    try:
        device_id = data.get('deviceId')
        status    = data.get('status', {})
        pool      = get_pool()

        updates = ['is_online = TRUE', 'last_seen = NOW()']
        values  = []
        idx     = 1

        if status.get('batteryLevel')       is not None:
            updates.append('battery_level = %s');        values.append(status['batteryLevel'])
        if status.get('wifiSignalStrength') is not None:
            updates.append('wifi_signal_strength = %s'); values.append(status['wifiSignalStrength'])
        if status.get('firmwareVersion')    is not None:
            updates.append('firmware_version = %s');     values.append(status['firmwareVersion'])
        if status.get('compartments')       is not None:
            updates.append('compartments = %s');         values.append(json.dumps(status['compartments']))

        values.append(device_id)
        await pool.execute(
            f"UPDATE dispensers SET {', '.join(updates)} WHERE device_id = %s",
            *values,
        )
        await sio.emit('dispenser:status', status, room=f'patient:{device_id}')
    except Exception as e:
        print(f'[Socket.IO] device:status error: {e}')


# ESP32 confirms dose dispensed
@sio.on('device:dispensed')
async def on_device_dispensed(sid, data):
    try:
        device_id    = data.get('deviceId')
        compartment  = data.get('compartment')
        confirmed_at = data.get('confirmedAt')
        pool         = get_pool()

        row = await pool.fetchrow(
            """UPDATE dose_records
               SET status = 'taken', taken_time = %s, dispensed_by_device = TRUE
               WHERE id = (
                 SELECT id FROM dose_records
                 WHERE dispenser_compartment = %s AND status = 'pending'
                 ORDER BY scheduled_time ASC LIMIT 1
               ) RETURNING *""",
            confirmed_at, compartment,
        )
        if row:
            await sio.emit('dose:confirmed', {
                'doseId': str(row['id']), 'compartment': compartment,
            }, room=f'patient:{device_id}')
            print(f'[Socket.IO] Dose confirmed by device: compartment {compartment}')
    except Exception as e:
        print(f'[Socket.IO] device:dispensed error: {e}')


# Flutter app subscribes to device updates
@sio.on('patient:subscribe')
async def on_patient_subscribe(sid, data):
    device_id = data.get('deviceId')
    await sio.enter_room(sid, f'patient:{device_id}')
    print(f'[Socket.IO] App subscribed to device: {device_id}')


# ═══════════════════════════════════════════════════════════════════════════════
# ASGI App — Socket.IO wraps FastAPI
# Socket.IO handles /socket.io/ paths, FastAPI handles everything else
# ═══════════════════════════════════════════════════════════════════════════════
app = socketio.ASGIApp(sio, fastapi_app)
