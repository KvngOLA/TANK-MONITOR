import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import dotenv from "dotenv";
// import * as schema from "@/schema"
import { schema } from "./schema";

dotenv.config({ path: ".env" });

let db: ReturnType<typeof drizzle>;

/** Initialize the PostgreSQL connection pool and drizzle instance */
export function initDb() {
  // 1. Configure the Pool
  const pool = new Pool({
    connectionString: process.env.POSTGRES_CONNECTION,
    max: 10, // Maximum number of clients in the pool
    idleTimeoutMillis: 30000, // How long a client is allowed to sit idle before being closed
    connectionTimeoutMillis: 2000, // How long to wait for a connection before timing out
  });
  db = drizzle(pool, { schema });
  console.log("Postgres connection pool initialized");
}

/** Persist a telemetry reading */
export async function saveTelemetry(data: {
  level: number;
  ph: number;
  timestamp?: string;
}) {
  if (!db) {
    throw new Error("DB not initialized");
  }
  const { level, ph, timestamp } = data;

  try {
    await db.transaction(async (tx) => {
      await tx.insert(schema.telemetry).values({
        level,
        ph: ph.toString(),
        created_at: timestamp ? new Date(timestamp) : new Date(),
      });

      await tx.insert(schema.logs).values({
        event: `Telemetry received: level=${level}, ph=${ph}`,
      });
    });
  } catch (error) {
    console.error("Failed to save telemetry:", error);
  }
}

/**
 * Get all telemetry data
 */
export async function getAllTelemetry() {
  if (!db) {
    throw new Error("DB not initialized");
  }
  return db.select().from(schema.telemetry);
}

/** Simple helper to get the drizzle instance elsewhere */
export function getDb() {
  if (!db) throw new Error("DB not initialized");
  return db;
}
