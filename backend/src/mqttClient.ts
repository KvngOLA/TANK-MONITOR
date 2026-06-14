import mqtt, { MqttClient } from "mqtt";
import dotenv from "dotenv";
import type { Server as SocketIOServer } from "socket.io";
import { saveTelemetry } from "./db";

dotenv.config({ path: ".env" });

let client: MqttClient;

// GLOBAL CACHE: Tracks the physical state of the pump in memory
let currentPumpState = "OFF";

export function initMqtt(io: SocketIOServer) {
  const options = {
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD,
    keepalive: 60,
    clean: true,
    reconnectPeriod: 1000,
    connectTimeout: 30000,
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

        // Synchronize our global cache if the hardware sends an automatic update
        if (data.pump_status) {
          currentPumpState = data.pump_status.toString().toUpperCase();
        }

        io.emit("telemetry", data);
        console.log("Pushing to app: ", data.level);

        saveTelemetry(data).catch((err) => {
          console.error("Background DB Save Error:", err);
        });
      } catch (e) {
        console.error("Failed to process MQTT message", e);
      }
    }
  });

  // SOCKET INTERCEPTOR FOR APP BUTTON SYNC
  io.on("connection", (socket) => {
    console.log(`Mobile client connected: ${socket.id}`);

    // FRESH-OPENING TRIGGER: Send the real-time state to the app immediately on boot
    socket.emit("pump-status", { isPumpActive: currentPumpState === "ON" });

    // INTERACTIVE APP OVERRIDE: Listens for the user tapping the toggle button in Flutter
    socket.on("toggle-pump-request", (requestedState: string) => {
      currentPumpState = requestedState.toUpperCase();

      // 1. Broadcast the change to ALL running apps instantly to flip button colors
      io.emit("command-published", { state: currentPumpState });

      // 2. Forward the physical action packet to the hardware broker topic for the ESP32
      const commandTopic = process.env.MQTT_TOPIC_COMMAND || "pump/command";
      client.publish(commandTopic, currentPumpState, { qos: 1 }, (err) => {
        if (err)
          console.error("Failed to forward command to MQTT hardware:", err);
      });
    });
  });

  // expose client on io for command publishing
  (io as any).mqttClient = client;
}
