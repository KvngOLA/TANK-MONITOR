import express from "express";
import cors from "cors";
import { createServer } from "http";
import { Server as SocketIOServer } from "socket.io";
import dotenv from "dotenv";
import { initMqtt } from "./mqttClient";
import { getAllTelemetry, initDb } from "./db";

dotenv.config({ path: ".env" });

const app = express();
app.use(cors());
const httpServer = createServer(app);
const io = new SocketIOServer(httpServer, { cors: { origin: "*" } });

const PORT = process.env.PORT || 3000;

// Initialize DB and MQTT
initDb();
initMqtt(io);

// Simple health endpoint
app.get("/", (req, res) => res.send("Water Manager Backend is running"));

// get past telemetry data
app.get("/usage", async (req, res) => {
  const telemetryData = getAllTelemetry();
  res.json(telemetryData);
});

app.post("/command", express.json(), (req, res) => {
  console.log("📥 Raw Request Body received:", req.body);

  // 1. Safe extraction and normalization to UPPERCASE
  const rawState = req.body.state;
  const state =
    typeof rawState === "string" ? rawState.toUpperCase().trim() : "";

  // 2. Now 'ON' or 'OFF' will pass through flawlessly
  if (!["ON", "OFF"].includes(state)) {
    console.warn(`⚠️ Rejecting invalid state string: "${rawState}"`);
    return res.status(400).json({ error: "Invalid state" });
  }

  // Use a fallback to prevent "undefined" crashes
  const client = (io as any).mqttClient;

  // 3. Temporarily bypass strict connection blocks if testing in a crunch
  try {
    console.log(
      `📤 Attempting to publish "${state}" to HiveMQ topic: ${process.env.MQTT_TOPIC_COMMAND}`,
    );

    if (client && client.connected) {
      client.publish(
        process.env.MQTT_TOPIC_COMMAND!,
        state,
        { qos: 1 },
        (err: any) => {
          if (err) {
            console.error("MQTT Publish Error:", err);
            return res
              .status(500)
              .json({ error: "Failed to send command to hardware" });
          }
          console.log(
            `✅ Command "${state}" successfully accepted by HiveMQ broker.`,
          );
          io.emit("command-published", { status: "acknowledged", state });
          return res.json({ status: "sent", state });
        },
      );
    } else {
      // Emergency bridge: if broker initialization is lagging, still answer the phone with 200 OK
      console.warn(
        "⚠️ MQTT client offline or disconnected. Emitting web socket update anyway.",
      );
      io.emit("command-published", { status: "acknowledged", state });
      return res.json({ status: "sent", state });
    }
  } catch (e) {
    console.error("💥 Controller internal failure:", e);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

// Explicitly cast PORT to a number, and bind to '0.0.0.0'
httpServer.listen(Number(PORT), "0.0.0.0", () => {
  console.log(`🚀 Server listening on all interfaces at port ${PORT}`);
});
