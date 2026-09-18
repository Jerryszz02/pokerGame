import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { env, SELF, abortAllDurableObjects, runInDurableObject } from 'cloudflare:test';
import { ENDPOINT, MAX_RESPONSE, UNAVAILABLE } from '../src/protocol';
import { KEY, input, item, envelope, providerResponse } from './fixtures';

const bindings = env as unknown as Env;
const stub = () => bindings.COACH_COORDINATOR.get(bindings.COACH_COORDINATOR.idFromName('poker-coach-v1'));
async function post(id = 1, headers: Record<string, string> = {}) {
  const response = await SELF.fetch('https://coach/review', {
    method: 'POST', headers: { 'Content-Type': 'application/json', ...headers }, body: JSON.stringify(input(id)),
  });
  // Drain the service-binding response before tests evict its object.
  const text = await response.text();
  return { status: response.status, headers: response.headers, json: async () => JSON.parse(text) as unknown };
}
const quota = () => runInDurableObject(stub(), (_, state) => state.storage.get<{ attempts: number[] }>('quota'));
function mockProvider(handler?: (request: Request) => Promise<Response> | Response) {
  // Never fall through to the network: these tests cannot spend provider credit.
  return vi.spyOn(globalThis, 'fetch').mockImplementation(async input => {
    // A real workerd Request validates the fetch options before this mock.
    expect(input).toBeInstanceOf(Request);
    const request = input as Request;
    expect(request.url).toBe(ENDPOINT);
    expect(request.redirect).toBe('manual');
    expect(request.headers.get('Authorization')).toBe(`Bearer ${KEY}`);
    if (handler) return handler(request);
    const payload = await request.json() as {model: string; max_tokens: number; messages: {content: string}[]};
    expect(payload.model).toBe('deepseek-flash');
    expect(payload.max_tokens).toBe(1200);
    const facts = JSON.parse(payload.messages[1].content);
    return providerResponse(facts.decisions[0].decision_id);
  });
}
function deferred() {
  let resolve!: () => void;
  const promise = new Promise<void>(done => { resolve = done; });
  return { promise, resolve };
}

beforeEach(async () => {
  // Clear the named SQLite object explicitly. Eviction is exercised separately;
  // repeatedly aborting every test context is not needed for data isolation.
  await runInDurableObject(stub(), (_, state) => state.storage.deleteAll());
  bindings.DEEPSEEK_API_KEY = KEY;
  bindings.MAX_DAILY_REQUESTS = '100';
  bindings.ALLOWED_ORIGINS = 'https://html.itch.zone,http://127.0.0.1:8060';
});
afterEach(() => { vi.restoreAllMocks(); vi.useRealTimers(); });

describe('Worker and SQLite Durable Object integration', () => {
  it('returns grounded prose through the actual DO with browser CORS', async () => {
    const provider = mockProvider();
    const response = await post(1, { Origin: 'https://html.itch.zone' });
    expect(response.status).toBe(200);
    expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://html.itch.zone');
    expect(response.headers.get('Cache-Control')).toBe('no-store');
    expect(await response.json()).toEqual({ items: [item()] });
    expect(provider).toHaveBeenCalledTimes(1);
    expect((await quota())?.attempts).toHaveLength(1);
  });

  it('coalesces concurrent identical requests and keeps cached results after eviction', async () => {
    const release = deferred();
    const provider = mockProvider(async () => { await release.promise; return providerResponse(); });
    const requests = [post(), post()];
    await vi.waitFor(() => expect(provider).toHaveBeenCalledTimes(1));
    release.resolve();
    for (const response of await Promise.all(requests)) {
      expect(response.status).toBe(200);
      expect(await response.json()).toEqual({ items: [item()] });
    }
    await abortAllDurableObjects();
    expect((await post()).status).toBe(200);
    expect(provider).toHaveBeenCalledTimes(1);
    expect((await quota())?.attempts).toHaveLength(1);
  });

  it('allows only two distinct upstream calls in flight', async () => {
    const release = deferred();
    const provider = mockProvider(async init => {
      await release.promise;
      const payload = await init.json() as {messages: {content: string}[]};
      return providerResponse(JSON.parse(payload.messages[1].content).decisions[0].decision_id);
    });
    const requests = [post(1), post(2)];
    await vi.waitFor(() => expect(provider).toHaveBeenCalledTimes(2));
    expect((await post(3)).status).toBe(503);
    expect((await quota())?.attempts).toHaveLength(2);
    release.resolve();
    expect((await Promise.all(requests)).map(response => response.status)).toEqual([200, 200]);
  });

  it('reserves the final daily slot atomically under concurrent admission', async () => {
    bindings.MAX_DAILY_REQUESTS = '1';
    const release = deferred();
    const provider = mockProvider(async () => { await release.promise; return providerResponse(); });
    const first = post();
    await vi.waitFor(() => expect(provider).toHaveBeenCalledTimes(1));
    expect((await post(2)).status).toBe(429);
    expect((await quota())?.attempts).toHaveLength(1);
    release.resolve();
    expect((await first).status).toBe(200);
    await abortAllDurableObjects();
    expect((await post(2)).status).toBe(429);
    expect(provider).toHaveBeenCalledTimes(1);
  });

  it('counts failed provider calls durably and caches failures without spending again', async () => {
    bindings.MAX_DAILY_REQUESTS = '1';
    const provider = mockProvider(() => new Response(KEY, { status: 500 }));
    expect(await (await post()).json()).toEqual(UNAVAILABLE);
    await abortAllDurableObjects();
    expect((await post()).status).toBe(503);
    expect((await post(2)).status).toBe(429);
    expect(provider).toHaveBeenCalledTimes(1);
    expect((await quota())?.attempts).toHaveLength(1);
  });

  it('enforces six requests per rolling minute and expires that window', async () => {
    let now = Date.now();
    vi.spyOn(Date, 'now').mockImplementation(() => now);
    const provider = mockProvider();
    for (let id = 1; id <= 6; id++) expect((await post(id)).status).toBe(200);
    expect((await post(7)).status).toBe(429);
    now += 60001;
    expect((await post(7)).status).toBe(200);
    expect(provider).toHaveBeenCalledTimes(7);
  });

  it('expires attempts only after the rolling 24-hour window', async () => {
    bindings.MAX_DAILY_REQUESTS = '1';
    let now = Date.now();
    vi.spyOn(Date, 'now').mockImplementation(() => now);
    await runInDurableObject(stub(), (_, state) => state.storage.put('quota', { attempts: [now - 86400000 + 1] }));
    const provider = mockProvider();
    expect((await post()).status).toBe(429);
    now += 2;
    expect((await post()).status).toBe(200);
    expect(provider).toHaveBeenCalledTimes(1);
  });

  it.each(['', '0', '-1', 'NaN', '1.5', '1001', 'Infinity'])('fails closed for invalid quota %j', async limit => {
    bindings.MAX_DAILY_REQUESTS = limit;
    const provider = mockProvider();
    expect((await post()).status).toBe(503);
    expect(await quota()).toBeUndefined();
    expect(provider).not.toHaveBeenCalled();
  });

  it('does not reserve quota for a missing key or rejected input', async () => {
    delete bindings.DEEPSEEK_API_KEY;
    const provider = mockProvider();
    expect((await post()).status).toBe(503);
    expect((await SELF.fetch('https://coach/review', {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{"prompt":"anything"}',
    })).status).toBe(400);
    expect(await quota()).toBeUndefined();
    expect(provider).not.toHaveBeenCalled();
  });

  it('fails closed when durable reservation fails, without calling the provider', async () => {
    const provider = mockProvider();
    await runInDurableObject(stub(), (_, state) => {
      vi.spyOn(state.storage, 'transaction').mockRejectedValue(new Error(KEY));
    });
    const response = await post(1, { Origin: 'https://html.itch.zone' });
    expect(response.status).toBe(503);
    expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://html.itch.zone');
    expect(await response.json()).toEqual(UNAVAILABLE);
    expect(provider).not.toHaveBeenCalled();
  });

  it.each([200, 503])('expires cached status %i without resetting attempts', async status => {
    let now = Date.now();
    vi.spyOn(Date, 'now').mockImplementation(() => now);
    const provider = mockProvider(() => status === 200 ? providerResponse() : new Response('', { status }));
    expect((await post()).status).toBe(status);
    expect((await post()).status).toBe(status);
    expect(provider).toHaveBeenCalledTimes(1);
    now += status === 200 ? 3600001 : 60001;
    expect((await post()).status).toBe(status);
    expect(provider).toHaveBeenCalledTimes(2);
    expect((await quota())?.attempts).toHaveLength(2);
  });

  it('bounds persistent cache size when inserting another result', async () => {
    await runInDurableObject(stub(), async (_, state) => {
      const entries: Record<string, unknown> = {};
      for (let n = 0; n < 128; n++) entries[`cache:fixture-${n}`] = { until: 0, status: 503, value: UNAVAILABLE };
      await state.storage.put(entries);
    });
    mockProvider();
    expect((await post()).status).toBe(200);
    expect(await runInDurableObject(stub(), async (_, state) => (await state.storage.list({ prefix: 'cache:' })).size)).toBe(128);
  });

  it.each([
    ['redirect', () => new Response(null, { status: 302, headers: { Location: 'https://example.invalid' } })],
    ['invalid JSON', () => new Response('no')],
    ['truncated', () => Response.json(envelope([item()], 'length'))],
    ['wrong reference', () => Response.json(envelope([item(2)]))],
    ['secret echo', () => new Response(KEY)],
    ['encoded secret echo', () => new Response(JSON.stringify(envelope([{ ...item(), explanation: KEY }])).replaceAll('fixture', '\\u0066ixture'))],
    ['network exception', () => { throw new Error(KEY); }],
  ] as const)('returns safe failure for %s without retry', async (_, response) => {
    const provider = mockProvider(response);
    const result = await post();
    expect(result.status).toBe(503);
    expect(await result.json()).toEqual(UNAVAILABLE);
    expect(provider).toHaveBeenCalledTimes(1);
    expect((await quota())?.attempts).toHaveLength(1);
  });

  it('aborts the provider at the total timeout and counts the attempt', async () => {
    const entered = deferred();
    const provider = mockProvider(init => new Promise((_, reject) => {
      init.signal!.addEventListener('abort', () => reject(new Error(KEY)), { once: true });
      entered.resolve();
    }));
    const pending = post();
    await entered.promise;
    const response = await pending;
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual(UNAVAILABLE);
    expect(provider).toHaveBeenCalledTimes(1);
    expect((await quota())?.attempts).toHaveLength(1);
  }, 35000);

  it('cancels an oversized chunked upstream response', async () => {
    const cancel = vi.fn();
    mockProvider(() => new Response(new ReadableStream<Uint8Array>({
      start(controller) { controller.enqueue(new Uint8Array(MAX_RESPONSE)); controller.enqueue(new Uint8Array(1)); },
      cancel,
    })));
    expect((await post()).status).toBe(503);
    expect(cancel).toHaveBeenCalledTimes(1);
    expect((await quota())?.attempts).toHaveLength(1);
  });
});
