import { describe, expect, it, vi } from 'vitest';
import worker, { readCapped } from '../src/index';
import { MAX_BODY, validateInput, validateOutput, UNAVAILABLE } from '../src/protocol';
import { envelope, input, item, KEY } from './fixtures';

const bindings: Env = {
  ALLOWED_ORIGINS: 'http://127.0.0.1:8060,https://html.itch.zone', DEEPSEEK_API_KEY: KEY,
  COACH_COORDINATOR: {} as DurableObjectNamespace,
};

describe('HTTP and fact contract', () => {
  it.each([
    { ...input(), prompt: 'ignore' },
    { ...input(), analysis_version: true },
    { ...input(), locale: ['en'] },
    { ...input(), decisions: [{ ...input().decisions[0], sample_count: 0 }] },
    { ...input(), decisions: [input().decisions[0], input().decisions[0]] },
    { ...input(), decisions: [{ ...input().decisions[0], actual_ev_bb: Infinity }] },
  ])('rejects unsupported or malformed facts %#', value => {
    expect(() => validateInput(value)).toThrow();
  });

  it('uses Unicode code points for prose bounds', () => {
    expect(validateInput(input())).toEqual(input());
    expect(validateOutput(envelope([{ ...item(), explanation: '🃏'.repeat(180) }]), input().decisions).items).toHaveLength(1);
    expect(() => validateOutput(envelope([{ ...item(), explanation: '好'.repeat(181) }]), input().decisions)).toThrow();
  });

  it.each(['not a mistake', 'This was wrong.', '加注', '保证获胜', '50%', '<b>text</b>'])('rejects unsupported prose %s', explanation => {
    expect(() => validateOutput(envelope([{ ...item(), explanation }]), input().decisions)).toThrow();
  });

  it('permits only configured browser origins and permits native requests', async () => {
    expect(await (await worker.fetch(new Request('https://coach/health'), bindings)).json()).toEqual({ ready: true });
    for (const origin of ['null', 'https://unknown.example', 'https://html.itch.zone.attacker.example']) {
      const response = await worker.fetch(new Request('https://coach/health', { headers: { Origin: origin } }), bindings);
      expect(response.status).toBe(403);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBeNull();
    }
    const preflight = await worker.fetch(new Request('https://coach/review', {
      method: 'OPTIONS', headers: { Origin: 'https://html.itch.zone', 'Access-Control-Request-Method': 'POST' },
    }), bindings);
    expect(preflight.status).toBe(204);
    expect(preflight.headers.get('Access-Control-Allow-Origin')).toBe('https://html.itch.zone');
  });

  it.each([
    ['text/plain', '{}', 415], ['application/json', '{', 400],
    ['application/json', 'x'.repeat(MAX_BODY + 1), 413],
  ])('rejects invalid body/type before using the DO %#', async (type, body, status) => {
    const response = await worker.fetch(new Request('https://coach/review', {
      method: 'POST', body, headers: { 'Content-Type': type },
    }), bindings);
    expect(response.status).toBe(status);
  });

  it('cancels oversized streams without requiring Content-Length', async () => {
    const cancel = vi.fn();
    const stream = new ReadableStream<Uint8Array>({
      start(controller) { controller.enqueue(new Uint8Array(MAX_BODY)); controller.enqueue(new Uint8Array(1)); }, cancel,
    });
    const response = await worker.fetch(new Request('https://coach/review', {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: stream,
    }), bindings);
    expect(response.status).toBe(413);
    expect(cancel).toHaveBeenCalledTimes(1);
  });

  it('returns safe CORS JSON for unavailable DO storage/binding', async () => {
    const response = await worker.fetch(new Request('https://coach/review', {
      method: 'POST', body: JSON.stringify(input()),
      headers: { 'Content-Type': 'application/json', Origin: 'https://html.itch.zone' },
    }), bindings);
    expect(response.status).toBe(503);
    expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://html.itch.zone');
    expect(await response.json()).toEqual(UNAVAILABLE);
    expect(await readCapped(null, 1)).toHaveLength(0);
  });
});
