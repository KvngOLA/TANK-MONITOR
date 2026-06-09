#include <WiFi.h>
#include <PubSubClient.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// ==================== Configuration ====================
// Replace with your Wi‑Fi credentials
const char* WIFI_SSID = "RICHARD 8131";
const char* WIFI_PASS = "1234567r";

// MQTT broker configuration – HiveMQ Cloud
const char* MQTT_BROKER   = "7ff454f846764c1aa4d60c7862a3c072.s1.eu.hivemq.cloud";
const int   MQTT_PORT     = 8883;
const char* MQTT_USER     = "Olaoluwa";
const char* MQTT_PASSWORD = "skul_crusheR1"; // <-- Fixed: Added missing semicolon

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
  String msg;
  for (unsigned int i = 0; i < length; ++i) {
    msg += (char)payload[i];
  }
  msg.trim();
  Serial.print("MQTT command received: ");
  Serial.println(msg);

  if (msg.equalsIgnoreCase("ON")) {
    pumpOn = true; 
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
  float pct = (EMPTY_DISTANCE - dist) / (EMPTY_DISTANCE - FULL_DISTANCE) * 100.0;
  return constrain(pct, 0.0, 100.0);
}

float readPH() {
  int raw = analogRead(PH_PIN);
  return map(raw, 0, 4095, 0, 140) / 10.0;
}

// -------------------- Control logic --------------------
void controlPump(float levelPct) {
  if (!pumpOn && levelPct >= 0 && levelPct < LOW_LEVEL_PCT) {
    pumpOn = true;
  }
  if (pumpOn && levelPct >= HIGH_LEVEL_PCT) {
    pumpOn = false;
  }
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
    
    // Fixed Auto-shutdown: Only shut down if it is an OVERFLOW or unsafe pH.
    // If it's critically low, we NEED the pump to turn on, not shut off!
    if (levelPct > 95.0 || ph < PH_LOW || ph > PH_HIGH) {
      pumpOn = false;
    }
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
// Fixed: Expanded to send mapped percentage and string status for the UI toggle
void publishTelemetry(float levelCm, float levelPct, float ph) {
  String pumpStatusString = pumpOn ? "ACTIVE" : "INACTIVE";
  
  String payload = "{";
  payload += "\"level\":" + String(levelCm, 2);
  payload += ",\"level_pct\":" + String(levelPct, 2);
  payload += ",\"ph\":" + String(ph, 2);
  payload += ",\"pump_status\":\"" + pumpStatusString + "\"";
  payload += ",\"ts\":" + String(millis());
  payload += "}";
  
  client.publish(TOPIC_TELEMETRY, payload.c_str());
  Serial.print("MQTT publish: ");
  Serial.println(payload);
}

void loop() {
  if (!client.connected()) {
    reconnectMQTT();
  }
  client.loop(); 

  unsigned long now = millis();

  if (now - lastTelemetry >= TELEMETRY_INTERVAL) {
    lastTelemetry = now;

    float distance   = readDistance();
    float levelPct   = distanceToPercent(distance);
    float ph         = readPH();

    controlPump(levelPct);
    updatePumpOutput();
    handleAlarm(levelPct, ph);
    updateLCD(levelPct, ph);
    
    // Pass the calculated levelPct directly into telemetry
    publishTelemetry(distance, levelPct, ph);

    // Serial debug output
    Serial.println("--- Telemetry ---");
    Serial.print("Distance(cm): "); Serial.println(distance);
    Serial.print("Level(%): "); Serial.println(levelPct);
    Serial.print("pH: "); Serial.println(ph);
    Serial.print("Pump: "); Serial.println(pumpOn?"ON":"OFF");
    Serial.print("Alarm: "); Serial.println(alarmActive?"ACTIVE":"CLEAR");
  }
}