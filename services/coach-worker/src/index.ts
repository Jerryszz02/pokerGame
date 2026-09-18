import {
  ENDPOINT, MAX_BODY, MAX_RESPONSE, UNAVAILABLE, makePayload, validateInput, validateOutput,
  type Review, type ReviewResult,
} from "./protocol";

export { MAX_BODY, validateInput, validateOutput } from "./protocol";
const DAY = 24 * 60 * 60 * 1000;
const MINUTE = 60 * 1000;
const PROVIDER_TIMEOUT = 25 * 1000;
interface Result { status: number; value: ReviewResult }
interface CacheEntry extends Result { until: number }
interface Quota { attempts: number[] }

function hasKey(env: Env): boolean {
  return typeof env.DEEPSEEK_API_KEY === "string" && /^[\x21-\x7e]{16,512}$/.test(env.DEEPSEEK_API_KEY);
}

function dailyLimit(env: Env): number {
  const text = env.MAX_DAILY_REQUESTS ?? "100";
  if (!/^[1-9][0-9]{0,3}$/.test(text) || Number(text) > 1000) throw Error("quota configuration");
  return Number(text);
}

function origins(env: Env): Set<string> {
  return new Set((env.ALLOWED_ORIGINS ?? "").split(",").map(origin => origin.trim()).filter(Boolean));
}

export async function readCapped(stream: ReadableStream<Uint8Array> | null, limit: number): Promise<Uint8Array> {
  if (!stream) return new Uint8Array();
  const reader = stream.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const part = await reader.read();
      if (part.done) break;
      total += part.value.byteLength;
      if (total > limit) {
        void reader.cancel("body too large").catch(() => undefined);
        throw Error("body too large");
      }
      chunks.push(part.value);
    }
  } finally {
    reader.releaseLock();
  }
  const result = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) { result.set(chunk, offset); offset += chunk.byteLength; }
  return result;
}

function cors(request: Request, env: Env, headers?: HeadersInit): Headers {
  const result = new Headers(headers);
  result.set("Vary", "Origin");
  result.set("Cache-Control", "no-store");
  const origin = request.headers.get("Origin");
  if (origin && origins(env).has(origin)) {
    result.set("Access-Control-Allow-Origin", origin);
    result.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    result.set("Access-Control-Allow-Headers", "Content-Type");
  }
  return result;
}

function json(value: unknown, status = 200): Response {
  return Response.json(value, { status });
}

async function callProvider(review: Review, key: string): Promise<Result> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), PROVIDER_TIMEOUT);
  try {
    const request = new Request(ENDPOINT, {
      method: "POST", redirect: "manual", signal: controller.signal,
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
      body: JSON.stringify(makePayload(review)),
    });
    const upstream = await fetch(request);
    if (!upstream.ok) {
      void upstream.body?.cancel().catch(() => undefined);
      throw Error("upstream");
    }
    const bytes = await readCapped(upstream.body, MAX_RESPONSE);
    const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    if (text.includes(key)) throw Error("upstream response");
    const value = validateOutput(JSON.parse(text), review.decisions);
    if (value.items.some(item => item.explanation.includes(key) || item.next_step.includes(key))) {
      throw Error("upstream response");
    }
    return { status: 200, value };
  } catch {
    return { status: 503, value: UNAVAILABLE };
  } finally {
    clearTimeout(timer);
  }
}

export class ReviewCoordinator {
  private readonly active = new Map<string, Promise<Result>>();

  constructor(private readonly state: DurableObjectState, private readonly env: Env) {}

  async fetch(request: Request): Promise<Response> {
    try {
      const body = validateInput(await request.json());
      const limit = dailyLimit(this.env);
      if (!hasKey(this.env)) return json(UNAVAILABLE, 503);
      const key = await hash(stable(body));
      const cached = await this.state.storage.get<CacheEntry>(`cache:${key}`);
      if (cached && cached.until > Date.now()) return json(cached.value, cached.status);

      let work = this.active.get(key);
      if (work) {
        const result = await work;
        return json(result.value, result.status);
      }
      if (this.active.size >= 2) return json(UNAVAILABLE, 503);
      work = this.perform(body, key, limit);
      this.active.set(key, work);
      try {
        const result = await work;
        return json(result.value, result.status);
      } finally {
        this.active.delete(key);
      }
    } catch {
      return json(UNAVAILABLE, 503);
    }
  }

  private async reserve(limit: number): Promise<boolean> {
    // Commit the attempt before network access. Failures and object eviction
    // cannot refund it. No network calls or side effects inside the transaction.
    return this.state.storage.transaction(async transaction => {
      const now = Date.now();
      const saved = await transaction.get<Quota>("quota");
      if (saved && (!Array.isArray(saved.attempts) ||
          saved.attempts.some(time => !Number.isSafeInteger(time) || time < 0))) {
        throw Error("quota storage");
      }
      const attempts = (saved?.attempts ?? []).filter(time => time > now - DAY);
      if (attempts.length >= limit || attempts.filter(time => time > now - MINUTE).length >= 6) return false;
      attempts.push(now);
      await transaction.put("quota", { attempts });
      return true;
    });
  }

  private async perform(body: Review, key: string, limit: number): Promise<Result> {
    if (!await this.reserve(limit)) return { status: 429, value: UNAVAILABLE };
    const result = await callProvider(body, this.env.DEEPSEEK_API_KEY!);
    const until = Date.now() + (result.status === 200 ? 60 * MINUTE : MINUTE);
    await this.state.storage.transaction(async transaction => {
      await transaction.put(`cache:${key}`, { ...result, until });
      const entries = await transaction.list<CacheEntry>({ prefix: "cache:" });
      const excess = entries.size - 128;
      if (excess > 0) {
        const oldest = [...entries].sort((a, b) => a[1].until - b[1].until).slice(0, excess);
        await transaction.delete(oldest.map(([name]) => name));
      }
    });
    return result;
  }
}

function stable(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stable).join(",")}]`;
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    return `{${Object.keys(record).sort().map(key => JSON.stringify(key) + ":" + stable(record[key])).join(",")}}`;
  }
  return JSON.stringify(value);
}

async function hash(text: string): Promise<string> {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(bytes)].map(byte => byte.toString(16).padStart(2, "0")).join("");
}

async function handle(request: Request, env: Env): Promise<Response> {
  const path = new URL(request.url).pathname;
  const origin = request.headers.get("Origin");
  if (origin === "null" || (origin && !origins(env).has(origin))) return json(UNAVAILABLE, 403);
  if (request.method === "OPTIONS") return path === "/review" ? new Response(null, { status: 204 }) : json(UNAVAILABLE, 404);
  if (request.method === "GET" && path === "/health") {
    dailyLimit(env);
    return json({ ready: hasKey(env) });
  }
  if (request.method !== "POST" || path !== "/review") return json(UNAVAILABLE, 404);
  if (request.headers.get("Content-Type")?.split(";")[0].trim().toLowerCase() !== "application/json") {
    return json(UNAVAILABLE, 415);
  }
  const length = request.headers.get("Content-Length");
  if (length && (!/^\d+$/.test(length) || Number(length) > MAX_BODY)) return json(UNAVAILABLE, 413);
  let bytes: Uint8Array;
  try { bytes = await readCapped(request.body, MAX_BODY); }
  catch { return json(UNAVAILABLE, 413); }
  let value: Review;
  try { value = validateInput(JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes))); }
  catch { return json(UNAVAILABLE, 400); }
  const id = env.COACH_COORDINATOR.idFromName("poker-coach-v1");
  return env.COACH_COORDINATOR.get(id).fetch("https://coordinator/review", {
    method: "POST", body: JSON.stringify(value),
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    let response: Response;
    try { response = await handle(request, env); }
    catch { response = json(UNAVAILABLE, 503); }
    return new Response(response.body, {
      status: response.status, headers: cors(request, env, response.headers),
    });
  },
};
