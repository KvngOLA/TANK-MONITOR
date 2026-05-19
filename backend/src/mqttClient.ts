import mqtt, { MqttClient } from "mqtt";
import dotenv from "dotenv";
import type { Server as SocketIOServer } from "socket.io";
import { saveTelemetry } from "./db";

dotenv.config({ path: ".env" });

let client: MqttClient;

export function initMqtt(io: SocketIOServer) {
  const options = {
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD,
    keepalive: 60, // Keep connection alive by pinging HiveMQ every 60 seconds
    clean: true, // Establish a fresh session
    reconnectPeriod: 1000, // Auto-reconnect every 1 second if dropped
    connectTimeout: 30000, // 30 second timeout window
    rejectUnauthorized: true,
  };
  client = mqtt.connect(process.env.MQTT_BROKER_URL!, options);

  client.on("connect", () => {
    console.log("Connected to MQTT broker");
    client.subscribe(process.env.MQTT_TOPIC_DATA!, (err) => {
      if (err) console.error("Subscribe error:", err);
    });
  });

  client.on("message", (topic, payload) => {
    if (topic === process.env.MQTT_TOPIC_DATA) {
      try {
        const data = JSON.parse(payload.toString());
        // Expected shape: { level: number, ph: number, timestamp?: string }
        io.emit("telemetry", data);
        console.log("Pushing to app: ", data.level);

        // SAVE TO DATABASE IN BACKGROUND (Non-blocking)
        saveTelemetry(data).catch((err) => {
          console.error("Background DB Save Error:", err);
        });
      } catch (e) {
        console.error("Failed to process MQTT message", e);
      }
    }
  });

  // expose client on io for command publishing
  (io as any).mqttClient = client;
}
