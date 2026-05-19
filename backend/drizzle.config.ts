import "dotenv/config";
import { Config, defineConfig } from "drizzle-kit";

declare const process: { env: Record<string, string | undefined> };

export default defineConfig({
  schema: "./src/schema.ts",
  out: "./src/migrations",
  dialect: "postgresql",
  dbCredentials: {
    url: process.env.POSTGRES_CONNECTION!,
  },
} satisfies Config);
