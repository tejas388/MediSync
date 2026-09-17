# backend/socket_manager.py
# MediSync - Shared Socket.IO server instance
# Import `sio` and `connected_devices` wherever needed

import socketio

sio = socketio.AsyncServer(
    async_mode='asgi',
    cors_allowed_origins='*',
    logger=False,
    engineio_logger=False,
)

# deviceId → socket session id
connected_devices: dict = {}
