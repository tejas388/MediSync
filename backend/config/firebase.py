# backend/config/firebase.py
# MediSync - Firebase Admin SDK (replaces config/firebase.js)

import os
import json
import base64
import firebase_admin
from firebase_admin import credentials, auth, messaging


_initialized = False


def init_firebase():
    global _initialized
    if firebase_admin._apps:
        _initialized = True
        return

    cred = None

    # Option 1: base64-encoded JSON in env variable
    b64 = os.getenv('FIREBASE_SERVICE_ACCOUNT_BASE64')
    if b64:
        cert_dict = json.loads(base64.b64decode(b64).decode('utf-8'))
        cred = credentials.Certificate(cert_dict)

    # Option 2: path to service account JSON file
    if not cred:
        path = os.getenv('FIREBASE_SERVICE_ACCOUNT_PATH', './config/serviceAccountKey.json')
        if os.path.exists(path):
            cred = credentials.Certificate(path)
        else:
            print(f'[Firebase] Service account file not found at: {path}')
            print('[Firebase] Running without Firebase Admin — token verification disabled')
            return

    firebase_admin.initialize_app(cred)
    _initialized = True
    print('✅ Firebase Admin SDK initialized')


async def verify_firebase_token(id_token: str) -> dict:
    if not firebase_admin._apps:
        raise Exception('Firebase Admin not initialized')
    # firebase_admin.auth is synchronous — run in thread pool in production
    decoded = auth.verify_id_token(id_token)
    return decoded


async def send_fcm_notification(fcm_token: str, title: str, body: str, data: dict = {}):
    if not firebase_admin._apps or not fcm_token:
        return
    try:
        is_interactive = data.get('type') == 'doseReminder'
        
        msg_data = {k: str(v) for k, v in data.items()}
        if is_interactive:
            msg_data['title'] = title
            msg_data['body'] = body

        message = messaging.Message(
            token=fcm_token,
            notification=None if is_interactive else messaging.Notification(title=title, body=body),
            data=msg_data,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    channel_id='medisync_reminders',
                    sound='default',
                ) if not is_interactive else None,
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound='default', badge=1, content_available=True)
                )
            ),
        )
        messaging.send(message)
        print(f'[FCM] Sent to ...{fcm_token[-6:]}: {title}')
    except Exception as e:
        print(f'[FCM] Send error: {e}')


async def send_fcm_multicast(fcm_tokens: list, title: str, body: str, data: dict = {}):
    if not firebase_admin._apps or not fcm_tokens:
        return
    try:
        message = messaging.MulticastMessage(
            tokens=fcm_tokens,
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in data.items()},
            android=messaging.AndroidConfig(priority='high'),
        )
        response = messaging.send_each_for_multicast(message)
        print(f'[FCM] Multicast: {response.success_count}/{len(fcm_tokens)} delivered')
    except Exception as e:
        print(f'[FCM] Multicast error: {e}')
