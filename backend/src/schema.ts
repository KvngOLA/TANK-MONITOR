import {
  pgTable,
  serial,
  integer,
  numeric,
  timestamp,
  text,
} from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";

export const telemetry = pgTable("telemetry", {
  id: serial("id").primaryKey(),
  level: integer("level").notNull(), // water level in cm
  ph: numeric("ph", { precision: 3, scale: 2 }).notNull(), // pH value 0-14
  created_at: timestamp("created_at")
    .default(sql`now()`)
    .notNull(),
});

export const logs = pgTable("logs", {
  id: serial("id").primaryKey(),
  event: text("event").notNull(),
  created_at: timestamp("created_at")
    .default(sql`now()`)
    .notNull(),
});

export const schema = {
  telemetry,
  logs,
};
