# MediSync 💊

> **IoT-powered automated medicine dispenser** — Flutter + Node.js + ESP32 + Firebase Auth

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-18+-339933?logo=nodedotjs)](https://nodejs.org)
[![MongoDB](https://img.shields.io/badge/MongoDB-8.x-47A248?logo=mongodb)](https://mongodb.com)
[![Firebase](https://img.shields.io/badge/Firebase-Auth+FCM-FFCA28?logo=firebase)](https://firebase.google.com)
[![ESP32](https://img.shields.io/badge/ESP32-Arduino-E7352C?logo=arduino)](https://arduino.cc)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App                              │
│  Patient / Caregiver  │  Firebase Auth (login, Google Sign-In) │
│  Material 3 UI        │  Provider state management             │
└──────────────┬───────────────────────────┬──────────────────────┘
               │ HTTP (REST)               │ Token verify
               ▼                           ▼
┌─────────────────────────────┐   ┌────────────────────┐
│  Node.js / Express Backend  │   │   Firebase Auth    │
│  MongoDB (Mongoose)         │◄──│   (ID token verify)│
│  Socket.IO (real-time)      │   └────────────────────┘
│  FCM push via Admin SDK     │
│  PDF reports (PDFKit)       │
│  Cron scheduler             │
└──────────────┬──────────────┘
               │ Socket.IO / REST
               ▼
┌─────────────────────────────┐
│  ESP32 Dispenser            │
│  7× servo compartments      │
│  OLED display               │
│  Buzzer + LEDs              │
│  Battery monitoring         │
└─────────────────────────────┘
```

---

## 📁 Project Structure

```
main/
├── lib/                          # Flutter app
│   ├── main.dart                 # Entry point
│   ├── core/
│   │   ├── constants/            # Colors, constants
│   │   ├── theme/                # Material 3 light + dark
│   │   ├── services/             # API, notifications, biometric
│   │   ├── extensions/           # Dart extensions + validators
│   │   └── errors/               # Exception hierarchy
│   ├── models/                   # Plain JSON models
│   └── features/
│       ├── auth/                 # Login, register, forgot password
│       ├── dashboard/            # Patient home, caregiver dashboard
│       ├── medicines/            # List, add/edit, detail
│       ├── history/              # Dose history with filters
│       ├── analytics/            # Charts, streaks, adherence
│       ├── dispenser/            # ESP32 status + manual control
│       ├── notifications/        # In-app notification center
│       ├── reports/              # PDF generation + sharing
│       └── profile/              # Profile + settings
│
├── backend/                      # Node.js / Express
│   ├── server.js                 # Entry + Socket.IO
│   ├── config/                   # MongoDB, Firebase Admin
│   ├── middleware/               # Firebase token verification
│   ├── models/                   # Mongoose schemas
│   ├── controllers/              # Business logic
│   ├── routes/                   # API route definitions
│   └── services/                 # FCM, scheduler (cron)
│
└── esp32_firmware/
    └── medisync_dispenser.ino    # Arduino firmware
```

---

## 🚀 Quick Start

### 1. Firebase Setup (Auth only)
1. Go to [Firebase Console](https://console.firebase.google.com) → Create project
2. Enable **Email/Password** and **Google** sign-in methods
3. Add Android app → Download `google-services.json` → place in `android/app/`
4. Generate **Service Account** key → save as `backend/config/serviceAccountKey.json`

### 2. Backend Setup
```bash
cd backend
cp .env.example .env        # Fill in your values
npm install
node server.js              # or: npm run dev
```

**Required `.env` values:**
```env
MONGO_URI=mongodb://localhost:27017/medisync
FIREBASE_SERVICE_ACCOUNT_PATH=./config/serviceAccountKey.json
PORT=5000
ESP32_AUTH_TOKEN=your_device_secret
```

### 3. Flutter Setup
```bash
flutter pub get
flutter run
```

**Change the backend URL** in `lib/core/services/api_service.dart`:
```dart
static const String _baseUrl = 'http://YOUR_PC_IP:5000/api/v1';
```

> **Android emulator:** use `http://10.0.2.2:5000/api/v1`  
> **Physical device on same WiFi:** use your PC's local IP

### 4. Android Build Config
In `android/app/build.gradle` set:
```gradle
minSdkVersion 23    // Required for biometric auth
targetSdkVersion 34
```

### 5. ESP32 Setup
1. Install Arduino libraries:
   - `ArduinoJson`
   - `ESP32Servo`
   - `Adafruit_SSD1306`
   - `Adafruit_GFX`
   - `arduinoWebSockets` (SocketIOclient)
2. Edit `esp32_firmware/medisync_dispenser.ino`:
   ```cpp
   const char* WIFI_SSID     = "Your_WiFi";
   const char* WIFI_PASSWORD = "Your_Password";
   const char* BACKEND_HOST  = "192.168.x.x";  // Your backend IP
   const char* DEVICE_ID     = "ESP32_001";
   const char* DEVICE_AUTH_TOKEN = "your_device_secret"; // Match .env
   ```
3. Flash to ESP32

---

## 📱 Features

| Feature | Status |
|---------|--------|
| Email + Google Sign-In (Firebase Auth) | ✅ |
| Patient & Caregiver roles | ✅ |
| Medicine CRUD (name, dosage, compartment, schedule) | ✅ |
| Local & FCM push reminders | ✅ |
| Mark taken / Snooze / Missed | ✅ |
| Low stock & expiry alerts | ✅ |
| Dose history with filters | ✅ |
| Adherence analytics + bar chart | ✅ |
| Streak tracking | ✅ |
| Caregiver monitoring (real-time) | ✅ |
| Missed dose FCM → caregivers | ✅ |
| ESP32 auto-dispense (Socket.IO) | ✅ |
| Manual dispense from app | ✅ |
| Emergency SOS | ✅ |
| PDF report (download + share) | ✅ |
| Biometric login | ✅ |
| Light + Dark mode (Material 3) | ✅ |

---

## 🔌 API Reference

Base URL: `http://localhost:5000/api/v1`

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/sync` | Sync Firebase profile to MongoDB |
| GET | `/auth/me` | Get current user profile |
| GET | `/medicines` | List medicines |
| POST | `/medicines` | Add medicine |
| PUT | `/medicines/:id` | Update medicine |
| DELETE | `/medicines/:id` | Delete medicine |
| GET | `/doses/today` | Today's dose schedule |
| PATCH | `/doses/:id/take` | Mark dose as taken |
| PATCH | `/doses/:id/snooze` | Snooze dose |
| GET | `/analytics/adherence?days=7` | Adherence stats |
| GET | `/analytics/streak` | Current & longest streak |
| GET | `/dispenser/status` | Device status |
| POST | `/dispenser/dispense` | Manual dispense |
| POST | `/dispenser/emergency` | Emergency SOS |
| GET | `/reports/pdf` | Download PDF report |
| GET | `/caregiver/patients` | List linked patients |
| GET | `/notifications` | In-app notifications |

---

## 🔧 ESP32 Hardware Wiring

| Component | ESP32 GPIO |
|-----------|-----------|
| Servo C1 | GPIO 13 |
| Servo C2 | GPIO 12 |
| Servo C3 | GPIO 14 |
| Servo C4 | GPIO 27 |
| Servo C5 | GPIO 26 |
| Servo C6 | GPIO 25 |
| Servo C7 | GPIO 33 |
| OLED SDA | GPIO 21 |
| OLED SCL | GPIO 22 |
| Buzzer | GPIO 4 |
| US Trig | GPIO 5 |
| US Echo | GPIO 18 |
| Battery ADC | GPIO 34 |

---

## 🛡️ Security

- Firebase ID token verified on **every** API request via Firebase Admin SDK
- Rate limiting (100 req / 15 min) on all endpoints
- Helmet.js HTTP security headers
- ESP32 authenticated with a shared secret token over Socket.IO
- All passwords handled exclusively by Firebase Auth (never stored in MongoDB)

---

## 📄 License

MIT © 2025 MediSync — Final Year Engineering Project
