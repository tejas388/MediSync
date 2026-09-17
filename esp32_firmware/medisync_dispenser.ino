// ─────────────────────────────────────────────────────────────────────────────
// esp32_firmware/medisync_dispenser.ino
// MediSync ESP32 Firmware v1.0
//
// Hardware:
//   - ESP32 Dev Module
//   - 7× SG90 servo motors (one per compartment, GPIO 13,12,14,27,26,25,33)
//   - HC-SR04 ultrasonic sensor (Trig: GPIO 5, Echo: GPIO 18) for stock detection
//   - SSD1306 OLED 128×64 (I2C: SDA 21, SCL 22)
//   - Active buzzer (GPIO 4)
//   - WS2812B LED ring (GPIO 19) - status indicator
//   - LiPo battery + voltage divider (GPIO 34 ADC)
//
// Communication:
//   - WiFi → Node.js backend REST API (heartbeat + manual commands)
//   - Socket.IO → real-time dispense commands
// ─────────────────────────────────────────────────────────────────────────────

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <ESP32Servo.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <SocketIOclient.h>
#include <WebSocketsClient.h>
#include <time.h>

// ─── WiFi Credentials ────────────────────────────────────────────────────────
const char* WIFI_SSID     = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// ─── Backend Config ───────────────────────────────────────────────────────────
const char* BACKEND_HOST      = "192.168.1.100";   // Your Node.js server IP
const int   BACKEND_PORT      = 5000;
const char* BACKEND_BASE_URL  = "http://192.168.1.100:5000/api/v1";
const char* DEVICE_ID         = "ESP32_MEDISYNC_001";
const char* DEVICE_AUTH_TOKEN = "esp32_secret_device_token_change_in_production";

// ─── Hardware Pins ────────────────────────────────────────────────────────────
const int SERVO_PINS[7]   = {13, 12, 14, 27, 26, 25, 33};
const int BUZZER_PIN       = 4;
const int US_TRIG_PIN      = 5;
const int US_ECHO_PIN      = 18;
const int BATTERY_ADC_PIN  = 34;
const int LED_PIN          = 19;
const int OLED_SDA         = 21;
const int OLED_SCL         = 22;

// ─── Servo Config ─────────────────────────────────────────────────────────────
const int SERVO_CLOSED_ANGLE = 0;    // degrees — compartment closed
const int SERVO_OPEN_ANGLE   = 90;   // degrees — compartment open
const int DISPENSE_DURATION_MS = 800; // how long to hold open

// ─── Timing ────────────────────────────────────────────────────────────────────
const unsigned long HEARTBEAT_INTERVAL_MS  = 30000;  // 30s heartbeat to API
const unsigned long WIFI_RETRY_INTERVAL_MS = 5000;
const unsigned long STATUS_CHECK_MS        = 5000;   // check for pending dispense

// ─── Global Objects ────────────────────────────────────────────────────────────
Servo           servos[7];
Adafruit_SSD1306 oled(128, 64, &Wire, -1);
SocketIOclient  socketIO;

unsigned long lastHeartbeat    = 0;
unsigned long lastStatusCheck  = 0;
bool          isSocketConnected = false;
int           compartmentStock[7] = {30, 30, 30, 30, 30, 30, 30}; // Counts

// ═════════════════════════════════════════════════════════════════════════════
// SETUP
// ═════════════════════════════════════════════════════════════════════════════
void setup() {
  Serial.begin(115200);
  Serial.println(F("\n[MediSync] ESP32 Firmware v1.0 starting..."));

  // Buzzer + LEDs
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(US_TRIG_PIN, OUTPUT);
  pinMode(US_ECHO_PIN, INPUT);
  digitalWrite(BUZZER_PIN, LOW);

  // OLED
  Wire.begin(OLED_SDA, OLED_SCL);
  if (!oled.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println(F("[OLED] Init failed!"));
  } else {
    oled.clearDisplay();
    oled.setTextSize(1);
    oled.setTextColor(SSD1306_WHITE);
    showOLED("MediSync", "Booting...", "");
  }

  // Attach servos (all closed)
  for (int i = 0; i < 7; i++) {
    servos[i].attach(SERVO_PINS[i]);
    servos[i].write(SERVO_CLOSED_ANGLE);
  }

  // Connect WiFi
  connectWiFi();

  // Sync NTP time
  configTime(19800, 0, "pool.ntp.org"); // IST = UTC+5:30

  // Connect Socket.IO
  connectSocketIO();

  // Startup beep
  beep(2, 100);

  showOLED("MediSync", "Ready!", DEVICE_ID);
  Serial.println(F("[MediSync] Setup complete!"));
}

// ═════════════════════════════════════════════════════════════════════════════
// LOOP
// ═════════════════════════════════════════════════════════════════════════════
void loop() {
  socketIO.loop();

  unsigned long now = millis();

  // Reconnect WiFi if lost
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
    return;
  }

  // Heartbeat to REST API every 30 s
  if (now - lastHeartbeat >= HEARTBEAT_INTERVAL_MS) {
    lastHeartbeat = now;
    sendHeartbeat();
  }

  // Poll for pending dispense commands via REST (fallback if Socket.IO drops)
  if (now - lastStatusCheck >= STATUS_CHECK_MS) {
    lastStatusCheck = now;
    checkPendingDispense();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WIFI
// ═════════════════════════════════════════════════════════════════════════════
void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  showOLED("WiFi", "Connecting...", WIFI_SSID);
  Serial.printf("[WiFi] Connecting to %s\n", WIFI_SSID);

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print('.');
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WiFi] Connected! IP: %s\n", WiFi.localIP().toString().c_str());
    showOLED("WiFi OK", WiFi.localIP().toString().c_str(), "");
    beep(1, 200);
  } else {
    Serial.println(F("\n[WiFi] Failed — retrying later"));
    showOLED("WiFi", "Failed", "Retrying...");
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SOCKET.IO
// ═════════════════════════════════════════════════════════════════════════════
void connectSocketIO() {
  Serial.printf("[Socket.IO] Connecting to %s:%d\n", BACKEND_HOST, BACKEND_PORT);
  socketIO.begin(BACKEND_HOST, BACKEND_PORT, "/socket.io/?EIO=4");
  socketIO.onEvent(socketIOEvent);
}

void socketIOEvent(socketIOmessageType_t type, uint8_t* payload, size_t length) {
  switch (type) {
    case sIOtype_DISCONNECT:
      isSocketConnected = false;
      Serial.println(F("[Socket.IO] Disconnected"));
      showOLED("Socket.IO", "Disconnected", "");
      break;

    case sIOtype_CONNECT:
      isSocketConnected = true;
      Serial.println(F("[Socket.IO] Connected!"));
      // Register this device
      {
        DynamicJsonDocument doc(256);
        doc["deviceId"] = DEVICE_ID;
        doc["token"]    = DEVICE_AUTH_TOKEN;
        String json;
        serializeJson(doc, json);
        socketIO.emit("device:register", json.c_str());
      }
      showOLED("Socket.IO", "Connected", DEVICE_ID);
      break;

    case sIOtype_EVENT: {
      String msg = String((char*)payload);
      Serial.printf("[Socket.IO] Event: %s\n", msg.c_str());

      DynamicJsonDocument doc(512);
      DeserializationError err = deserializeJson(doc, msg);
      if (err) break;

      String eventName = doc[0];

      // ── Scheduled / manual dispense ──────────────────────────────────────
      if (eventName == "dispense:scheduled" || eventName == "dispense:command") {
        int comp = doc[1]["compartmentNumber"] | 0;
        if (comp >= 1 && comp <= 7) {
          Serial.printf("[Dispense] Command received for C%d\n", comp);
          performDispense(comp);
        }
      }

      // ── Emergency dispense ───────────────────────────────────────────────
      else if (eventName == "dispense:emergency") {
        int comp = doc[1]["compartmentNumber"] | 1;
        Serial.println(F("[Dispense] EMERGENCY!"));
        beep(5, 100); // Alarm
        performDispense(comp);
        // Notify server
        reportDispenseComplete(comp, true);
      }

      // ── Device registered confirmation ───────────────────────────────────
      else if (eventName == "device:registered") {
        Serial.println(F("[Socket.IO] Device registered successfully"));
      }

      break;
    }

    default: break;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DISPENSE
// ═════════════════════════════════════════════════════════════════════════════
void performDispense(int compartment) {
  int idx = compartment - 1;
  if (idx < 0 || idx >= 7) return;

  Serial.printf("[Dispense] Opening compartment C%d\n", compartment);
  showOLED("Dispensing", ("C" + String(compartment)).c_str(), "Please wait...");

  // Open servo
  servos[idx].write(SERVO_OPEN_ANGLE);
  beep(1, 150);
  delay(DISPENSE_DURATION_MS);

  // Close servo
  servos[idx].write(SERVO_CLOSED_ANGLE);
  delay(300);

  // Decrease stock count
  if (compartmentStock[idx] > 0) compartmentStock[idx]--;

  Serial.printf("[Dispense] C%d dispensed. Stock remaining: %d\n",
                compartment, compartmentStock[idx]);

  beep(2, 80);
  showOLED("Dispensed!", ("C" + String(compartment)).c_str(),
           ("Stock: " + String(compartmentStock[idx])).c_str());

  delay(2000);
  showOLED("MediSync", "Ready!", DEVICE_ID);

  // Tell server dose was dispensed
  reportDispenseComplete(compartment, false);
}

void reportDispenseComplete(int compartment, bool emergency) {
  if (!isSocketConnected) return;

  DynamicJsonDocument doc(256);
  doc["deviceId"]    = DEVICE_ID;
  doc["compartment"] = compartment;
  doc["confirmedAt"] = getISOTime();
  doc["emergency"]   = emergency;

  String json;
  serializeJson(doc, json);
  socketIO.emit("device:dispensed", json.c_str());
  Serial.println(F("[Socket.IO] Dispense confirmed to server"));
}

// ═════════════════════════════════════════════════════════════════════════════
// HEARTBEAT (REST API)
// ═════════════════════════════════════════════════════════════════════════════
void sendHeartbeat() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(BACKEND_BASE_URL) + "/dispenser/heartbeat";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  // Build compartments array
  DynamicJsonDocument doc(1024);
  doc["deviceId"]           = DEVICE_ID;
  doc["batteryLevel"]       = readBatteryLevel();
  doc["wifiSignalStrength"] = WiFi.RSSI();
  doc["firmwareVersion"]    = "1.0.0";
  doc["isOnline"]           = true;

  JsonArray comps = doc.createNestedArray("compartments");
  for (int i = 0; i < 7; i++) {
    JsonObject c = comps.createNestedObject();
    c["number"] = i + 1;
    c["stock"]  = compartmentStock[i];
  }

  String body;
  serializeJson(doc, body);

  int code = http.POST(body);
  if (code == 200) {
    // Check if server has a pending dispense command
    String response = http.getString();
    DynamicJsonDocument res(512);
    if (!deserializeJson(res, response)) {
      JsonObject pending = res["data"];
      if (!pending.isNull()) {
        int comp = pending["compartmentNumber"] | 0;
        if (comp >= 1 && comp <= 7 && !pending["isAcknowledged"]) {
          Serial.printf("[Heartbeat] Pending dispense for C%d\n", comp);
          performDispense(comp);
        }
      }
    }
    Serial.println(F("[Heartbeat] OK"));
  } else {
    Serial.printf("[Heartbeat] Failed: %d\n", code);
  }

  http.end();

  // Update OLED status
  showOLED("MediSync", ("WiFi: " + String(WiFi.RSSI()) + "dBm").c_str(),
           ("Bat: " + String(readBatteryLevel()) + "%").c_str());
}

// ═════════════════════════════════════════════════════════════════════════════
// POLL FOR PENDING DISPENSE (REST fallback)
// ═════════════════════════════════════════════════════════════════════════════
void checkPendingDispense() {
  // Handled via heartbeat response — no separate call needed
}

// ═════════════════════════════════════════════════════════════════════════════
// UTILITIES
// ═════════════════════════════════════════════════════════════════════════════
int readBatteryLevel() {
  int raw = analogRead(BATTERY_ADC_PIN);
  // 12-bit ADC, 3.3V ref, voltage divider: (R1+R2)/R2 = 2
  float voltage = (raw / 4095.0) * 3.3 * 2.0;
  // LiPo: 3.0V = 0%, 4.2V = 100%
  int pct = constrain((int)((voltage - 3.0) / (4.2 - 3.0) * 100), 0, 100);
  return pct;
}

void beep(int count, int durationMs) {
  for (int i = 0; i < count; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(durationMs);
    digitalWrite(BUZZER_PIN, LOW);
    if (i < count - 1) delay(durationMs / 2);
  }
}

void showOLED(const char* line1, const char* line2, const char* line3) {
  oled.clearDisplay();
  oled.setCursor(0, 0);
  oled.setTextSize(1);
  oled.println(line1);
  oled.setCursor(0, 20);
  oled.setTextSize(1);
  oled.println(line2);
  if (strlen(line3) > 0) {
    oled.setCursor(0, 44);
    oled.setTextSize(1);
    oled.println(line3);
  }
  oled.display();
}

String getISOTime() {
  time_t now;
  struct tm ti;
  time(&now);
  gmtime_r(&now, &ti);
  char buf[25];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &ti);
  return String(buf);
}
