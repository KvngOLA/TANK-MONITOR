#include <WiFi.h>
#include <PubSubClient.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// ==================== Configuration ====================
// Replace with your Wi‑Fi credentials
const char* WIFI_SSID = "YOUR_SSID";
const char* WIFI_PASS = "YOUR_PASSWORD";

// MQTT broker configuration – HiveMQ Cloud
const char* MQTT_BROKER   = "YOUR_HIVEMQ_HOST"; // e.g., broker.hivemq.com or your cloud host
const int   MQTT_PORT     = 1883;
const char* MQTT_USER     = "YOUR_MQTT_USERNAME";
const char* MQTT_PASSWORD = "YOUR_MQTT_PASSWORD";

// MQTT topics
const char* TOPIC_TELEMETRY = "tank/data";   // publish telemetry JSON
const char* TOPIC_COMMAND   = "tank/command"; // subscribe for ON/OFF commands

// ==================== Control Thresholds ====================
const float LOW_LEVEL_PCT  = 20.0;  // Turn pump ON at 20%
const float HIGH_LEVEL_PCT = 90.0;  // Turn pump OFF at 90%

// ==================== Pin definitions ====================
#define TRIG_PIN     5
#define ECHO_PIN     18
#define BUZZER_PIN   19
#define PUMP_LED_PIN 23   // LED represents pump state; connect relay accordingly
#define PH_PIN       34

// ==================== LCD ====================
LiquidCrystal_I2C lcd(0x27, 16, 2);

// ==================== Tank parameters ====================
const float EMPTY_DISTANCE = 100.0; // cm when tank is empty
const float FULL_DISTANCE  = 10.0;  // cm when tank is full

// ==================== pH thresholds ====================
const float PH_LOW  = 6.5;
const float PH_HIGH = 8.5;

// ==================== Timing ====================
unsigned long lastTelemetry = 0;               // last MQTT publish time
const unsigned long TELEMETRY_INTERVAL = 5000; // 5 seconds (non‑blocking)

// ==================== State ====================
bool pumpOn      = false; // reflects the actual relay state
bool alarmActive = false; // buzzer active flag

// ==================== Wi‑Fi & MQTT ====================
WiFiClient   wifiClient;
PubSubClient client(wifiClient);

void setupWiFi() {
  Serial.print("Connecting to Wi‑Fi ");
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print('.');
  }
  Serial.println("\nWi‑Fi connected");
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  // Expect simple payload: "ON" or "OFF"
  String msg;
  for (unsigned int i = 0; i < length; ++i) {
    msg += (char)payload[i];
  }
  msg.trim();
  Serial.print("MQTT command received: ");
  Serial.println(msg);

  if (msg.equalsIgnoreCase("ON")) {
    pumpOn = true; // command tries to turn pump on
  } else if (msg.equalsIgnoreCase("OFF")) {
    pumpOn = false;
  }
}

void reconnectMQTT() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    if (client.connect("ESP32_TankMonitor", MQTT_USER, MQTT_PASSWORD)) {
      Serial.println(" connected");
      client.subscribe(TOPIC_COMMAND);
    } else {
      Serial.print(" failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 2s");
      delay(2000);
    }
  }
}

void setup() {
  Serial.begin(115200);

  pinMode(TRIG_PIN,     OUTPUT);
  pinMode(ECHO_PIN,     INPUT);
  pinMode(BUZZER_PIN,   OUTPUT);
  pinMode(PUMP_LED_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN,   LOW);
  digitalWrite(PUMP_LED_PIN, LOW);

  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0,0);
  lcd.print("Tank Monitor    ");
  lcd.setCursor(0,1);
  lcd.print("Initialising... ");
  delay(2000);
  lcd.clear();

  setupWiFi();
  client.setServer(MQTT_BROKER, MQTT_PORT);
  client.setCallback(mqttCallback);

  Serial.println("=== Tank Monitor Started ===");
}

// -------------------- Sensor helpers --------------------
float readDistance() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  long duration = pulseIn(ECHO_PIN, HIGH, 30000);
  if (duration == 0) return -1.0; // timeout
  return duration * 0.034 / 2.0; // cm
}

float distanceToPercent(float dist) {
  if (dist < 0) return -1.0;
  // Map distance to water level percentage (0 % = empty, 100 % = full)
  float pct = (dist - FULL_DISTANCE) / (EMPTY_DISTANCE - FULL_DISTANCE) * 100.0;
  return constrain(pct, 0.0, 100.0);
}

float readPH() {
  int raw = analogRead(PH_PIN);
  // Simulated pH 0‑14 via potentiometer
  return map(raw, 0, 4095, 0, 140) / 10.0;
}

// -------------------- Control logic --------------------
void controlPump(float levelPct) {
  // Original threshold logic
  if (!pumpOn && levelPct >= 0 && levelPct < LOW_LEVEL_PCT) {
    pumpOn = true;
  }
  if (pumpOn && levelPct >= HIGH_LEVEL_PCT) {
    pumpOn = false;
  }

  // Safety auto‑shutdown when tank is empty or full
  // Use distance cm values derived from levelPct if needed
  // Here we rely on handleAlarm to enforce shutdown via alarmActive flag if required
}

void updatePumpOutput() {
  digitalWrite(PUMP_LED_PIN, pumpOn ? HIGH : LOW);
}

void handleAlarm(float levelPct, float ph) {
  bool shouldAlarm = (levelPct >= 0 && levelPct < 10.0) || // critically low
                     (levelPct > 95.0) ||                 // near overflow
                     (ph < PH_LOW) ||
                     (ph > PH_HIGH);
  if (shouldAlarm) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(150);
    digitalWrite(BUZZER_PIN, LOW);
    alarmActive = true;
    // Auto‑shutdown pump in unsafe conditions
    pumpOn = false;
  } else {
    alarmActive = false;
  }
}

void updateLCD(float levelPct, float ph) {
  lcd.clear();
  lcd.setCursor(0,0);
  if (levelPct < 0) {
    lcd.print("Level: ERROR    ");
  } else {
    lcd.print("Level:");
    lcd.print((int)levelPct);
    lcd.print("%    ");
    lcd.setCursor(8,0);
    lcd.print(pumpOn?"PUMP:ON":"PUMP:OFF");
  }
  lcd.setCursor(0,1);
  lcd.print("pH:");
  lcd.print(ph,1);
  lcd.setCursor(8,1);
  if (levelPct >= 0 && levelPct < 10.0) {
    lcd.print("CRIT LOW");
  } else if (levelPct > 95.0) {
    lcd.print("OVERFLOW");
  } else if (ph < PH_LOW) {
    lcd.print("pH LOW! ");
  } else if (ph > PH_HIGH) {
    lcd.print("pH HIGH!");
  } else {
    lcd.print("OK      ");
  }
}

// -------------------- Telemetry --------------------
void publishTelemetry(float levelCm, float ph) {
  // Build a compact JSON payload
  String payload = "{";
  payload += "\"level\":" + String(levelCm, 2);
  payload += ",\"ph\":" + String(ph, 2);
  payload += ",\"ts\":" + String(millis()); // simple timestamp in ms since boot
  payload += "}";
  client.publish(TOPIC_TELEMETRY, payload.c_str());
  Serial.print("MQTT publish: ");
  Serial.println(payload);
}

void loop() {
  if (!client.connected()) {
    reconnectMQTT();
  }
  client.loop(); // process inbound MQTT messages

  unsigned long now = millis();

  // Sensor read & UI update (every 5 s)
  if (now - lastTelemetry >= TELEMETRY_INTERVAL) {
    lastTelemetry = now;

    float distance   = readDistance();
    float levelPct   = distanceToPercent(distance);
    float ph         = readPH();

    controlPump(levelPct);
    updatePumpOutput();
    handleAlarm(levelPct, ph);
    updateLCD(levelPct, ph);
    publishTelemetry(distance, ph);

    // Serial debug output
    Serial.println("--- Telemetry ---");
    Serial.print("Distance(cm): "); Serial.println(distance);
    Serial.print("Level(%): "); Serial.println(levelPct);
    Serial.print("pH: "); Serial.println(ph);
    Serial.print("Pump: "); Serial.println(pumpOn?"ON":"OFF");
    Serial.print("Alarm: "); Serial.println(alarmActive?"ACTIVE":"CLEAR");
  }
}
