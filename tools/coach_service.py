#!/usr/bin/env python3
"""Loopback replay prose service. Only this process reads the owner's API key."""
import argparse
from collections import OrderedDict, deque
import hashlib
import http.server
import json
import math
from pathlib import Path
import re
import threading
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
ENDPOINT = 'https://api.deepseek.com/chat/completions'
MODEL = 'deepseek-flash'
MAX_BODY = 16384
MAX_RESPONSE = 262144
ACTIONS = {'fold', 'check', 'call', 'raise', 'all_in'}
FACT_KEYS = {'decision_id', 'actual_action', 'actual_amount', 'alternative_action',
             'alternative_amount', 'actual_ev_bb', 'alternative_ev_bb', 'gap_bb',
             'assessment', 'sample_count'}
ORIGINS = {f'http://{host}:{port}' for host in ('127.0.0.1', 'localhost')
           for port in (8060, 8061)}
UNAVAILABLE = {'available': False, 'reason': 'unavailable'}


def read_key(path):
    """Re-read the designated file so filling it does not require a restart."""
    try:
        with Path(path).open(encoding='utf-8') as source:
            text = source.read(4097)
        if len(text) > 4096:
            return ''
        for line in text.splitlines():
            name, separator, value = line.partition('=')
            if separator and name.strip() == 'DEEPSEEK_API_KEY':
                value = value.strip()
                if value[:1] in ('"', "'") and value[-1:] == value[:1]:
                    value = value[1:-1]
                return value if re.fullmatch(r'[\x21-\x7e]{16,512}', value) else ''
    except (OSError, UnicodeError):
        pass
    return ''


def validate_input(value):
    if not isinstance(value, dict) or set(value) != {'analysis_version', 'locale', 'decisions'}:
        raise ValueError('request shape')
    if type(value['analysis_version']) is not int or value['analysis_version'] != 1:
        raise ValueError('analysis version')
    if value['locale'] not in ('en', 'zh_CN'):
        raise ValueError('locale')
    facts = value['decisions']
    if not isinstance(facts, list) or not 1 <= len(facts) <= 12:
        raise ValueError('decisions')
    seen = set()
    for fact in facts:
        if not isinstance(fact, dict) or set(fact) != FACT_KEYS:
            raise ValueError('fact shape')
        for name, maximum in (('decision_id', 4096), ('actual_amount', 10**9),
                              ('alternative_amount', 10**9), ('sample_count', 100000)):
            if type(fact[name]) is not int or not 0 <= fact[name] <= maximum:
                raise ValueError('integer fact')
        if fact['decision_id'] < 1 or fact['decision_id'] in seen or fact['sample_count'] < 1:
            raise ValueError('decision reference')
        seen.add(fact['decision_id'])
        for name in ('actual_action', 'alternative_action'):
            if not isinstance(fact[name], str) or fact[name] not in ACTIONS:
                raise ValueError('action')
        if fact['assessment'] not in ('close', 'compare'):
            raise ValueError('assessment')
        for name in ('actual_ev_bb', 'alternative_ev_bb', 'gap_bb'):
            number = fact[name]
            if type(number) not in (int, float) or abs(number) > 10**9 or not math.isfinite(number):
                raise ValueError('numerical fact')
    return value


def make_payload(value):
    language = 'English' if value['locale'] == 'en' else 'Simplified Chinese'
    instructions = (
        f'Write a brief poker practice explanation in {language} using ONLY supplied local-analysis facts. '
        'Return JSON only: {"items":[{"decision_id":1,"actual_action":"call",'
        '"alternative_action":"fold","assessment":"compare","explanation":"Short qualitative explanation",'
        '"next_step":"Short practice suggestion"}]}. '
        'Choose one to three distinct supplied decisions. Copy decision_id, actual_action, '
        'alternative_action and assessment exactly from that decision. '
        'Each text must be at most 180 characters. Do not write numbers, percentages, card names, '
        'imagined holdings, outcomes, or actions other than the two supplied actions in either text. '
        'The UI supplies all numeric values. These are approximate neutral-range sampled EVs, '
        'not optimal play. For close, acknowledge unresolved sampling uncertainty and do not call '
        'the action a mistake. Avoid the words mistake, wrong, incorrect, should have, 错误, 失误 and 必须 '
        'even in a negation. Describe uncertainty directly instead. '
        'For compare, invite comparison of sizing and future risk. Never guarantee success.'
    )
    return {'model': MODEL, 'stream': False, 'thinking': {'type': 'disabled'}, 'max_tokens': 1200,
            'response_format': {'type': 'json_object'},
            'messages': [{'role': 'system', 'content': instructions},
                         {'role': 'user', 'content': json.dumps({'decisions': value['decisions']})}]}


def validate_output(envelope, facts):
    choices = envelope.get('choices') if isinstance(envelope, dict) else None
    if not isinstance(choices, list) or len(choices) != 1 or not isinstance(choices[0], dict):
        raise ValueError('choices')
    choice = choices[0]
    if choice.get('finish_reason') != 'stop' or not isinstance(choice.get('message'), dict):
        raise ValueError('incomplete')
    content = choice['message'].get('content')
    if not isinstance(content, str) or len(content) > 6000:
        raise ValueError('content')
    parsed = json.loads(content)
    items = parsed.get('items') if isinstance(parsed, dict) else None
    if not isinstance(items, list) or not 1 <= len(items) <= 3:
        raise ValueError('items')
    by_id = {fact['decision_id']: fact for fact in facts}
    seen, output = set(), []
    aliases = {'fold': ('fold', '弃牌'), 'check': ('check', '过牌', '让牌'),
               'call': ('call', '跟注'), 'raise': ('raise', '加注'),
               'all_in': ('all-in', 'all in', '全下')}
    for item in items:
        if not isinstance(item, dict) or type(item.get('decision_id')) is not int:
            raise ValueError('reference')
        decision = item['decision_id']
        if decision not in by_id or decision in seen:
            raise ValueError('reference')
        fact = by_id[decision]
        clean = {'decision_id': decision}
        for name in ('actual_action', 'alternative_action', 'assessment'):
            if item.get(name) != fact[name]:
                raise ValueError('unsupported fact')
            clean[name] = fact[name]
        for name in ('explanation', 'next_step'):
            text = item.get(name)
            if not isinstance(text, str) or not text.strip() or len(text) > 180:
                raise ValueError('text')
            if re.search(r'[0-9０-９%％♠♣♥♦<>]|guarantee|always win|GTO|https?://|保证|必胜|百分之', text, re.I):
                raise ValueError('unsupported claim')
            lower = text.lower()
            if fact['assessment'] == 'close' and any(word in lower for word in
                    ('mistake', 'wrong', 'incorrect', 'should have', '错误', '失误', '必须')):
                raise ValueError('uncertainty')
            for action, words in aliases.items():
                if action not in (fact['actual_action'], fact['alternative_action']) and any(word in lower for word in words):
                    raise ValueError('unsupported action')
            clean[name] = text.strip()
        seen.add(decision)
        output.append(clean)
    return {'items': output}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def call_provider(key, payload):
    request = urllib.request.Request(ENDPOINT, data=json.dumps(payload).encode(),
                                     headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + key})
    with urllib.request.build_opener(NoRedirect()).open(request, timeout=25) as response:
        body = response.read(MAX_RESPONSE + 1)
    if len(body) > MAX_RESPONSE or key.encode() in body:
        raise ValueError('invalid response')
    return json.loads(body)


class ReviewService:
    def __init__(self, env_file, provider=call_provider, daily_limit=100):
        self.env_file, self.provider, self.daily_limit = Path(env_file), provider, daily_limit
        self.lock = threading.Lock()
        self.cache = OrderedDict()
        self.requests = deque()

    def review(self, value):
        value = validate_input(value)
        cache_key = hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()
        # Serialize outbound requests and coalesce reopen/seek requests for the same facts.
        if not self.lock.acquire(timeout=28):
            return 503, UNAVAILABLE
        try:
            now = time.monotonic()
            cached = self.cache.get(cache_key)
            if cached and cached[0] > now:
                return cached[1], cached[2]
            key = read_key(self.env_file)
            if not key:
                return 503, UNAVAILABLE
            while self.requests and now - self.requests[0] >= 86400:
                self.requests.popleft()
            if len(self.requests) >= self.daily_limit or sum(now - start < 60 for start in self.requests) >= 6:
                return 429, UNAVAILABLE
            self.requests.append(now)
            try:
                result = validate_output(self.provider(key, make_payload(value)), value['decisions'])
                status, ttl = 200, 3600
            except Exception:
                # Provider errors may contain credentials/body text. Never log or forward them.
                status, result, ttl = 503, UNAVAILABLE, 60
            self.cache[cache_key] = (time.monotonic() + ttl, status, result)
            self.cache.move_to_end(cache_key)
            while len(self.cache) > 128:
                self.cache.popitem(last=False)
            return status, result
        finally:
            self.lock.release()


class ReviewHandler(http.server.BaseHTTPRequestHandler):
    def setup(self):
        super().setup()
        self.connection.settimeout(5)

    def log_message(self, _format, *args):
        pass

    def allowed(self):
        port = self.server.server_port
        return (self.headers.get('Host') in (f'127.0.0.1:{port}', f'localhost:{port}')
                and self.headers.get('Origin') in (None, *ORIGINS))

    def respond(self, code, result):
        body = json.dumps(result).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Vary', 'Origin')
        if self.headers.get('Origin') in ORIGINS:
            self.send_header('Access-Control-Allow-Origin', self.headers['Origin'])
            self.send_header('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
        try:
            self.wfile.write(body)
        except (OSError, TimeoutError):
            pass  # A closed game still leaves the completed result in the service cache.

    def do_OPTIONS(self):
        self.respond(200 if self.allowed() and self.path == '/review' else 403, {})

    def do_GET(self):
        if not self.allowed():
            self.respond(403, UNAVAILABLE)
        elif self.path == '/health':
            self.respond(200, {'ready': bool(read_key(self.server.review_service.env_file))})
        else:
            self.respond(404, UNAVAILABLE)

    def do_POST(self):
        if not self.allowed():
            return self.respond(403, UNAVAILABLE)
        if self.path != '/review':
            return self.respond(404, UNAVAILABLE)
        if self.headers.get_content_type() != 'application/json' or self.headers.get('Transfer-Encoding'):
            return self.respond(415, UNAVAILABLE)
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= MAX_BODY:
                return self.respond(413, UNAVAILABLE)
            body = self.rfile.read(length)
            if len(body) != length:
                return self.respond(400, UNAVAILABLE)
            value = json.loads(body)
            status, result = self.server.review_service.review(value)
        except (ValueError, TypeError, UnicodeError, OSError):
            return self.respond(400, UNAVAILABLE)
        self.respond(status, result)


def create_server(env_file, port=8062, provider=call_provider, daily_limit=100):
    server = http.server.ThreadingHTTPServer(('127.0.0.1', port), ReviewHandler)
    server.review_service = ReviewService(env_file, provider, daily_limit)
    return server


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--env-file', type=Path, default=ROOT / '.env.local')
    parser.add_argument('--port', type=int, default=8062)
    parser.add_argument('--max-daily-requests', type=int, default=100)
    args = parser.parse_args()
    if args.max_daily_requests < 1:
        parser.error('--max-daily-requests must be positive')
    server = create_server(args.env_file, args.port, daily_limit=args.max_daily_requests)
    print(f'Coach service: http://127.0.0.1:{server.server_port} (key configured: {bool(read_key(args.env_file))})', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
