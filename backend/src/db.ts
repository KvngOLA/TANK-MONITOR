import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import dotenv from "dotenv";
import { sql } from "drizzle-orm";
// import * as schema from "@/schema"
import { schema } from "./schema";
import { telemetry } from "./schema";

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
  pump_status: "ACTIVE" | "INACTIVE";
  timestamp?: string;
}) {
  if (!db) {
    throw new Error("DB not initialized");
  }
  const { level, ph, timestamp, pump_status } = data;

  try {
    await db.transaction(async (tx) => {
      await tx.insert(schema.telemetry).values({
        level,
        ph: ph.toString(),
        pump_status,
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

export async function getAllChartTelemetry() {
  if (!db) {
    throw new Error("DB not initialized");
  }

  // Truncates the timestamp to the nearest hour (keeps date + hour intact)
  // This ensures chronological sorting remains perfect across multiple days or midnights
  return (
    db
      .select({
        timeKey:
          sql<string>`to_char(date_trunc('hour', ${telemetry.created_at}), 'YYYY-MM-DD HH24:00')`.as(
            "time_key",
          ),
        averageLevel:
          sql<number>`ROUND(AVG(${telemetry.level})::numeric, 1)`.as(
            "average_level",
          ),
      })
      .from(telemetry)
      // Filter for only the last 24 hours of data
      .where(sql`${telemetry.created_at} >= NOW() - INTERVAL '24 hours'`)
      // Group rows accurately by date-hour blocks
      .groupBy(sql`date_trunc('hour', ${telemetry.created_at})`)
      // Order strictly chronologically from the oldest hour to the absolute newest
      .orderBy(sql`date_trunc('hour', ${telemetry.created_at}) ASC`)
  );
}

/** Simple helper to get the drizzle instance elsewhere */
export function getDb() {
  if (!db) throw new Error("DB not initialized");
  return db;
}
