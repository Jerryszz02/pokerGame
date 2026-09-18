import { cloudflarePool, cloudflareTest } from "@cloudflare/vitest-pool-workers";
import { defineConfig } from "vitest/config";

const workers = { wrangler: { configPath: "./wrangler.toml" } };
export default defineConfig({ plugins: [cloudflareTest(workers)], test: { pool: cloudflarePool(workers) } });
