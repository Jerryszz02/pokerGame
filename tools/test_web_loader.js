'use strict';

// Dependency-free checks for tools/web_shell.html.
//
// The tests do not open a browser and do not touch the network. They extract the
// real inline loader from the shell, substitute the Godot export placeholders,
// and run it inside a Node `vm` context with a minimal fake DOM, fake Engine, and
// a deterministic fake clock. This exercises the exact shipping code path.

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const HTML_PATH = path.join(__dirname, 'web_shell.html');
const html = fs.readFileSync(HTML_PATH, 'utf8');

// --------------------------------------------------------------------------
// Minimal assertion helpers.
// --------------------------------------------------------------------------

function assert(condition, message) {
	if (!condition) {
		throw new Error(message || 'assertion failed');
	}
}

function equal(actual, expected, message) {
	if (actual !== expected) {
		throw new Error((message || 'equal') + ': expected ' + JSON.stringify(expected) + ', got ' + JSON.stringify(actual));
	}
}

function includes(haystack, needle, message) {
	if (typeof haystack !== 'string' || haystack.indexOf(needle) === -1) {
		throw new Error((message || 'includes') + ': expected ' + JSON.stringify(needle) + ' in ' + JSON.stringify(haystack));
	}
}

function excludes(haystack, needle, message) {
	if (typeof haystack === 'string' && haystack.indexOf(needle) !== -1) {
		throw new Error((message || 'excludes') + ': did not expect ' + JSON.stringify(needle) + ' in ' + JSON.stringify(haystack));
	}
}

// --------------------------------------------------------------------------
// Shell loading: extract the inline loader and resolve export placeholders.
// --------------------------------------------------------------------------

const DEFAULT_PLACEHOLDERS = {
	'$GODOT_PROJECT_NAME': 'PokerGame',
	'$GODOT_HEAD_INCLUDE': '',
	'$GODOT_URL': 'index.js',
	'$GODOT_CONFIG': JSON.stringify({
		executable: 'index',
		mainPack: 'index.pck',
		args: [],
		canvasId: 'canvas',
		serviceWorker: false,
		ensureCrossOriginIsolationHeaders: false,
		fileSizes: { 'index.wasm': 1048576, 'index.pck': 2097152 },
	}),
	'$GODOT_THREADS_ENABLED': 'true',
};

function extractLoader(source) {
	const match = source.match(/<script[^>]*id="poker-web-loader"[^>]*>([\s\S]*?)<\/script>/);
	if (!match) {
		throw new Error('inline loader script with id "poker-web-loader" was not found');
	}
	return match[1];
}

function resolvePlaceholders(source, overrides) {
	const map = Object.assign({}, DEFAULT_PLACEHOLDERS, overrides || {});
	return source.replace(/\$GODOT_[A-Z_]+/g, function (token) {
		return Object.prototype.hasOwnProperty.call(map, token) ? map[token] : token;
	});
}

// --------------------------------------------------------------------------
// Minimal fake DOM. Deliberately does not implement innerHTML/textual parsing:
// the loader is expected to render text through textContent only.
// --------------------------------------------------------------------------

const DOM_IDS = [
	'loading-overlay',
	'loading-status',
	'loading-progress',
	'loading-detail',
	'loading-notice',
	'retry-button',
	'error-details',
	'error-summary',
	'error-text',
	'loading-title',
	'canvas',
];

function makeElement(tagName) {
	const element = {
		tagName: tagName,
		nodeName: String(tagName).toUpperCase(),
		children: [],
		attributes: Object.create(null),
		style: {},
		classList: { add: function () {}, remove: function () {}, toggle: function () {} },
		hidden: false,
		textContent: '',
		value: 0,
		max: 100,
		src: '',
		async: false,
		focused: false,
		removed: false,
		parent: null,
		listeners: Object.create(null),
		onload: null,
		onerror: null,
		appendChild: function (child) {
			this.children.push(child);
			child.parent = this;
			return child;
		},
		removeChild: function (child) {
			const index = this.children.indexOf(child);
			if (index !== -1) {
				this.children.splice(index, 1);
			}
			return child;
		},
		remove: function () {
			this.removed = true;
			if (this.parent) {
				this.parent.removeChild(this);
			}
		},
		setAttribute: function (name, value) {
			this.attributes[name] = String(value);
		},
		getAttribute: function (name) {
			return Object.prototype.hasOwnProperty.call(this.attributes, name) ? this.attributes[name] : null;
		},
		removeAttribute: function (name) {
			delete this.attributes[name];
		},
		addEventListener: function (type, handler) {
			if (!this.listeners[type]) {
				this.listeners[type] = [];
			}
			this.listeners[type].push(handler);
		},
		removeEventListener: function (type, handler) {
			const handlers = this.listeners[type];
			if (!handlers) {
				return;
			}
			const index = handlers.indexOf(handler);
			if (index !== -1) {
				handlers.splice(index, 1);
			}
		},
		dispatch: function (type, event) {
			const handlers = (this.listeners[type] || []).slice();
			for (const handler of handlers) {
				handler(event || {});
			}
		},
		dispatchEvent: function (event) {
			this.dispatch(event && event.type, event);
		},
		focus: function () {
			this.focused = true;
		},
	};
	return element;
}

function makeDom() {
	const elements = Object.create(null);
	for (const id of DOM_IDS) {
		elements[id] = makeElement(id === 'loading-progress' ? 'progress' : 'div');
	}
	const body = makeElement('body');
	const documentElement = { lang: '' };
	const document = {
		body: body,
		documentElement: documentElement,
		title: '',
		getElementById: function (id) {
			return elements[id] || null;
		},
		createElement: function (tagName) {
			return makeElement(tagName);
		},
		createTextNode: function (text) {
			return { nodeType: 3, textContent: String(text) };
		},
		addEventListener: function () {},
		removeEventListener: function () {},
	};
	return { elements: elements, body: body, document: document };
}

// --------------------------------------------------------------------------
// Deterministic fake clock: no real timers, everything driven by advance().
// --------------------------------------------------------------------------

function makeClock() {
	let now = 0;
	let sequence = 0;
	const timers = new Map();

	function schedule(fn, ms, interval) {
		sequence += 1;
		const id = sequence;
		const delay = Math.max(0, Number(ms) || 0);
		timers.set(id, { fn: fn, due: now + delay, interval: interval ? Math.max(1, delay) : null });
		return id;
	}

	return {
		performance: { now: function () { return now; } },
		setTimeout: function (fn, ms) { return schedule(fn, ms, false); },
		setInterval: function (fn, ms) { return schedule(fn, ms, true); },
		clearTimeout: function (id) { timers.delete(id); },
		clearInterval: function (id) { timers.delete(id); },
		pending: function () { return timers.size; },
		advance: function (ms) {
			const target = now + (Number(ms) || 0);
			let guard = 0;
			for (;;) {
				let chosenId = null;
				let chosen = null;
				for (const entry of timers) {
					const id = entry[0];
					const timer = entry[1];
					if (timer.due > target) {
						continue;
					}
					if (chosen === null || timer.due < chosen.due || (timer.due === chosen.due && id < chosenId)) {
						chosenId = id;
						chosen = timer;
					}
				}
				if (chosen === null) {
					break;
				}
				now = chosen.due;
				if (chosen.interval === null) {
					timers.delete(chosenId);
				} else {
					chosen.due += chosen.interval;
				}
				chosen.fn();
				guard += 1;
				if (guard > 200000) {
					throw new Error('fake clock did not settle');
				}
			}
			now = target;
		},
	};
}

// --------------------------------------------------------------------------
// Minimal fake Engine matching the Godot 4.x Web JS API surface the shell uses.
// --------------------------------------------------------------------------

function makeEngine(options) {
	const opts = options || {};
	const calls = { constructed: 0, startGame: 0, missingFeatureArgs: null, startOptions: null };
	let resolveStart = null;
	let rejectStart = null;
	const startPromise = new Promise(function (resolve, reject) {
		resolveStart = resolve;
		rejectStart = reject;
	});

	function Engine(config) {
		this.config = config;
		calls.constructed += 1;
	}
	Engine.getMissingFeatures = function (features) {
		calls.missingFeatureArgs = features;
		return (opts.missing || []).slice();
	};
	Engine.prototype.startGame = function (startOptions) {
		calls.startGame += 1;
		calls.startOptions = startOptions;
		return startPromise;
	};
	Engine.calls = calls;
	Engine.resolveStart = resolveStart;
	Engine.rejectStart = rejectStart;
	return Engine;
}

// --------------------------------------------------------------------------
// Shell harness.
// --------------------------------------------------------------------------

function runShell(options) {
	const opts = options || {};
	const dom = makeDom();
	const clock = makeClock();
	const reloads = { count: 0 };
	const location = {
		href: opts.url || 'https://example.test/play/',
		reload: function () { reloads.count += 1; },
	};
	const win = makeElement('window');
	win.location = location;
	const navigator = { language: opts.language || 'en-US' };
	const engine = Object.prototype.hasOwnProperty.call(opts, 'engine') ? opts.engine : makeEngine(opts);

	const sandbox = {
		console: { log: function () {}, warn: function () {}, error: function () {}, info: function () {} },
		window: win,
		navigator: navigator,
		document: dom.document,
		performance: clock.performance,
		setTimeout: clock.setTimeout,
		clearTimeout: clock.clearTimeout,
		setInterval: clock.setInterval,
		clearInterval: clock.clearInterval,
		Engine: engine,
	};
	const context = vm.createContext(sandbox);
	let loader = resolvePlaceholders(extractLoader(html), opts.placeholders);
	vm.runInContext(loader, context, { filename: 'poker-web-loader.js' });

	return {
		dom: dom,
		clock: clock,
		location: location,
		reloads: reloads,
		win: win,
		navigator: navigator,
		engine: engine,
		sandbox: sandbox,
		context: context,
		appendedScript: dom.body.children[0] || null,
	};
}

function flush() {
	return new Promise(function (resolve) { setImmediate(resolve); });
}

function statusText(shell) { return shell.dom.elements['loading-status'].textContent; }
function detailText(shell) { return shell.dom.elements['loading-detail'].textContent; }
function noticeText(shell) { return shell.dom.elements['loading-notice'].textContent; }
function errorText(shell) { return shell.dom.elements['error-text'].textContent; }
function retryHidden(shell) { return shell.dom.elements['retry-button'].hidden; }
function overlayRemoved(shell) { return shell.dom.elements['loading-overlay'].removed; }
function windowListenerCount(shell, type) {
	return (shell.win.listeners[type] || []).length;
}

// --------------------------------------------------------------------------
// Tests.
// --------------------------------------------------------------------------

const tests = [];
function test(name, fn) {
	tests.push({ name: name, fn: fn });
}

test('shell uses every standard Godot export placeholder and a #canvas', function () {
	for (const token of ['$GODOT_PROJECT_NAME', '$GODOT_HEAD_INCLUDE', '$GODOT_URL', '$GODOT_CONFIG', '$GODOT_THREADS_ENABLED']) {
		includes(html, token, 'missing placeholder ' + token);
	}
	includes(html, 'id="canvas"', 'canvas id');
	includes(html, 'id="poker-web-loader"', 'stable loader id');
});

test('shell has no external resources, network endpoints, or innerHTML', function () {
	excludes(html, 'http://', 'no http endpoint');
	excludes(html, 'https://', 'no https endpoint');
	excludes(html, '<img', 'no image assets');
	excludes(html, '<link', 'no external stylesheets');
	excludes(html, '@import', 'no css imports');
	excludes(html, 'innerHTML', 'textContent only');
});

test('renders the English loading state and appends the exported startup script', function () {
	const shell = runShell({ language: 'en-US' });
	includes(statusText(shell), 'Loading PokerGame', 'initial status');
	equal(shell.dom.elements['loading-overlay'].hidden, false, 'overlay visible');
	equal(retryHidden(shell), true, 'retry hidden');
	equal(shell.dom.elements['error-details'].hidden, true, 'details hidden');
	assert(shell.appendedScript, 'startup script appended to body');
	equal(shell.appendedScript.src, 'index.js', 'startup script src');
	assert(shell.appendedScript.onload && shell.appendedScript.onerror, 'load handlers wired');
});

test('selects Simplified Chinese from navigator.language', function () {
	const shell = runShell({ language: 'zh-CN' });
	includes(statusText(shell), '\u6b63\u5728\u52a0\u8f7d', 'zh loading text');
	equal(shell.dom.elements['retry-button'].textContent, '\u91cd\u8bd5', 'zh retry');
	equal(shell.dom.elements['error-summary'].textContent, '\u6280\u672f\u7ec6\u8282', 'zh details');
	excludes(statusText(shell), 'Loading', 'not english');
});

test('calls getMissingFeatures with the exported thread flag and reports bytes as percent and MB', function () {
	const shell = runShell({ language: 'en-US' });
	shell.appendedScript.onload();
	equal(shell.engine.calls.missingFeatureArgs.threads, true, 'threads flag forwarded');
	equal(shell.engine.calls.startGame, 1, 'startGame called once');
	assert(typeof shell.engine.calls.startOptions.onProgress === 'function', 'onProgress provided');

	shell.engine.calls.startOptions.onProgress(524288, 1048576);
	includes(statusText(shell), '50%', 'percent shown');
	includes(statusText(shell), '0.5 MB / 1.0 MB', 'MB shown from bytes');
	includes(detailText(shell), 'after decompression', 'resource bytes are not wire bytes');
	equal(shell.dom.elements['loading-progress'].value, 50, 'progress value');
});

test('honors a disabled thread placeholder', function () {
	const shell = runShell({ placeholders: { '$GODOT_THREADS_ENABLED': 'false' } });
	shell.appendedScript.onload();
	equal(shell.engine.calls.missingFeatureArgs.threads, false, 'threads false');
});

test('still starts when the engine has no getMissingFeatures helper', function () {
	const engine = makeEngine();
	delete engine.getMissingFeatures;
	const shell = runShell({ engine: engine });
	shell.appendedScript.onload();
	equal(shell.engine.calls.startGame, 1, 'startGame still called');
});

test('removes the overlay and clears timers and listeners when startGame resolves', async function () {
	const shell = runShell();
	shell.appendedScript.onload();
	assert(shell.clock.pending() > 0, 'watchdog running during startup');
	shell.engine.resolveStart();
	await flush();
	equal(overlayRemoved(shell), true, 'overlay removed on resolution');
	equal(shell.clock.pending(), 0, 'timers cleared');
	equal(windowListenerCount(shell, 'unhandledrejection'), 0, 'unhandledrejection listener removed');
	equal(shell.reloads.count, 0, 'no automatic reload');
});

test('switches to the starting state and explains caching once all bytes are reported', function () {
	const shell = runShell();
	shell.appendedScript.onload();
	shell.engine.calls.startOptions.onProgress(1048576, 1048576);
	includes(statusText(shell), 'Starting the game', 'starting status');
	includes(detailText(shell), 'cached files', 'cache hint');
	equal(shell.dom.elements['loading-progress'].value, 100, 'progress full');
});

test('an indeterminate progress callback after completion cannot revert the starting state', function () {
	const shell = runShell();
	shell.appendedScript.onload();
	const progress = shell.engine.calls.startOptions.onProgress;
	progress(1048576, 1048576);
	progress(0, 0);
	includes(statusText(shell), 'Starting the game', 'still starting');
	excludes(statusText(shell), 'Downloading', 'not reverted to download');
});

test('shows a distinct connection error and Retry when the start promise rejects', async function () {
	const shell = runShell();
	shell.appendedScript.onload();
	shell.engine.rejectStart(new Error('net::ERR_CONNECTION_CLOSED'));
	await flush();
	includes(statusText(shell), 'could not be downloaded', 'friendly connection message');
	excludes(statusText(shell), 'ERR_CONNECTION_CLOSED', 'no raw technical text in the status line');
	equal(retryHidden(shell), false, 'retry visible');
	equal(shell.dom.elements['error-details'].hidden, false, 'details expanded container shown');
	includes(errorText(shell), 'kind: connection', 'classified as connection');
	includes(errorText(shell), 'ERR_CONNECTION_CLOSED', 'technical detail captured');
	equal(overlayRemoved(shell), false, 'overlay stays for the error state');
	equal(shell.reloads.count, 0, 'no automatic reload');
});

test('an unhandled rejection during startup is surfaced instead of leaving the splash', function () {
	const shell = runShell();
	shell.appendedScript.onload();
	shell.win.dispatch('unhandledrejection', { reason: new Error('Failed to fetch'), preventDefault: function () {} });
	includes(statusText(shell), 'could not be downloaded', 'connection classification');
	includes(errorText(shell), 'kind: connection', 'classified');
	includes(errorText(shell), 'source: unhandledrejection', 'source recorded');
	equal(retryHidden(shell), false, 'retry visible');
});

test('a startup script load failure shows a friendly error and Retry', function () {
	const shell = runShell();
	shell.appendedScript.onerror();
	includes(statusText(shell), 'startup script could not be loaded', 'friendly script message');
	includes(errorText(shell), 'kind: script', 'classified as script');
	equal(retryHidden(shell), false, 'retry visible');
	equal(shell.engine.calls.startGame, 0, 'engine never started');
	equal(shell.reloads.count, 0, 'no automatic reload');
});

test('a missing Engine global is reported as a startup script failure', function () {
	const shell = runShell({ engine: undefined });
	shell.appendedScript.onload();
	equal(shell.engine, undefined, 'no Engine global was provided');
	includes(statusText(shell), 'startup script could not be loaded', 'friendly script message');
	includes(errorText(shell), 'kind: script', 'classified as script');
	includes(errorText(shell), 'Engine is not available', 'technical reason recorded');
	equal(retryHidden(shell), false, 'retry visible');
});

test('missing browser features are distinct from connection errors', function () {
	const feature = 'WebGL2 - Check web browser configuration and hardware support';
	const shell = runShell({ missing: [feature] });
	shell.appendedScript.onload();
	includes(statusText(shell), 'missing features', 'friendly missing-feature message');
	excludes(statusText(shell), feature, 'technical feature name kept out of the status line');
	excludes(statusText(shell), 'could not be downloaded', 'not reported as a connection error');
	includes(errorText(shell), 'kind: missing', 'classified as missing');
	includes(errorText(shell), feature, 'technical feature detail captured');
	equal(shell.engine.calls.startGame, 0, 'engine never started');
	equal(retryHidden(shell), false, 'retry visible');
});

test('a stalled download warns without cancelling the load and clears when progress resumes', async function () {
	const shell = runShell();
	shell.appendedScript.onload();
	const progress = shell.engine.calls.startOptions.onProgress;
	progress(104857, 1048576);
	shell.clock.advance(20000);
	includes(noticeText(shell), 'slow or interrupted', 'slow warning shown');
	equal(shell.dom.elements['loading-notice'].hidden, false, 'notice visible');
	equal(retryHidden(shell), false, 'retry offered');
	equal(shell.engine.calls.startGame, 1, 'original load was not restarted');

	progress(524288, 1048576);
	equal(shell.dom.elements['loading-notice'].hidden, true, 'warning cleared when progress resumes');
	assert(shell.clock.pending() > 0, 'watchdog still active');
	shell.engine.resolveStart();
	await flush();
	equal(overlayRemoved(shell), true, 'load still completes after a stall');
});

test('repeated progress values do not postpone the stall warning', function () {
	const shell = runShell();
	shell.appendedScript.onload();
	const progress = shell.engine.calls.startOptions.onProgress;
	progress(100, 1000);
	for (let step = 0; step < 25; step += 1) {
		shell.clock.advance(1000);
		progress(100, 1000);
	}
	equal(retryHidden(shell), false, 'unchanged bytes are not progress');
});

test('a stalled startup script also offers Retry', function () {
	const shell = runShell();
	shell.clock.advance(20000);
	equal(retryHidden(shell), false, 'watchdog starts before the script arrives');
});

test('the observed TypeError network error is classified as a connection failure', function () {
	const shell = runShell();
	shell.win.dispatch('unhandledrejection', { reason: new Error('network error') });
	includes(errorText(shell), 'kind: connection', 'recognizes stream failure');
});

test('a slow but progressing download is never cancelled by total duration', function () {
	const shell = runShell();
	shell.appendedScript.onload();
	const progress = shell.engine.calls.startOptions.onProgress;
	for (let step = 1; step <= 6; step += 1) {
		shell.clock.advance(15000);
		progress(step * 100000, 1000000);
	}
	equal(shell.dom.elements['loading-notice'].hidden, true, 'no warning while progressing');
	equal(retryHidden(shell), true, 'no retry while progressing');
	equal(shell.engine.calls.startGame, 1, 'still the original load');
});

test('a startup stall after byte completion is non-fatal and still resolves', async function () {
	const shell = runShell();
	shell.appendedScript.onload();
	const progress = shell.engine.calls.startOptions.onProgress;
	progress(1048576, 1048576);
	includes(statusText(shell), 'Starting the game', 'starting status');
	shell.clock.advance(20000);
	includes(noticeText(shell), 'taking longer than expected', 'stall warning shown');
	equal(retryHidden(shell), false, 'retry offered');
	equal(overlayRemoved(shell), false, 'still loading');
	shell.engine.resolveStart();
	await flush();
	equal(overlayRemoved(shell), true, 'late resolution removes the overlay');
});

test('a resolution after a fatal unhandled rejection cannot hide the error UI', async function () {
	const shell = runShell();
	shell.appendedScript.onload();
	shell.win.dispatch('unhandledrejection', { reason: new Error('stream error') });
	shell.engine.resolveStart();
	await flush();
	equal(overlayRemoved(shell), false, 'overlay not removed');
	includes(statusText(shell), 'Something went wrong', 'fatal message preserved');
	equal(retryHidden(shell), false, 'retry still available');
});

test('clears timers and listeners after a fatal failure', async function () {
	const shell = runShell();
	shell.appendedScript.onload();
	assert(shell.clock.pending() > 0, 'watchdog running');
	shell.engine.rejectStart(new Error('ERR_CONNECTION_CLOSED'));
	await flush();
	equal(shell.clock.pending(), 0, 'timers cleared');
	equal(windowListenerCount(shell, 'unhandledrejection'), 0, 'listener removed');
	shell.win.dispatch('unhandledrejection', { reason: new Error('late') });
	includes(statusText(shell), 'could not be downloaded', 'fatal state unchanged');
});

test('Retry reloads the same page once and never auto-reloads', async function () {
	const shell = runShell();
	shell.appendedScript.onload();
	shell.engine.rejectStart(new Error('ERR_CONNECTION_CLOSED'));
	await flush();
	equal(shell.reloads.count, 0, 'nothing reloaded automatically');
	shell.dom.elements['retry-button'].dispatch('click');
	equal(shell.reloads.count, 1, 'retry reloads once');
});

test('the warning Retry button also reloads instead of cancelling silently', function () {
	const shell = runShell();
	shell.appendedScript.onload();
	shell.clock.advance(20000);
	equal(retryHidden(shell), false, 'warning offers retry');
	shell.dom.elements['retry-button'].dispatch('click');
	equal(shell.reloads.count, 1, 'reload once');
});

test('the failure UI is keyboard reachable and focuses Retry', function () {
	const shell = runShell();
	shell.appendedScript.onerror();
	equal(shell.dom.elements['retry-button'].focused, true, 'retry focused for keyboard users');
	includes(html, 'tabindex="0"', 'shell surfaces are focusable');
	includes(html, 'role="alert"', 'warnings announced');
	includes(html, 'aria-live="polite"', 'status announced');
});

// --------------------------------------------------------------------------
// Runner.
// --------------------------------------------------------------------------

(async function main() {
	let passed = 0;
	const failures = [];
	for (const entry of tests) {
		try {
			await entry.fn();
			passed += 1;
			console.log('ok - ' + entry.name);
		} catch (err) {
			failures.push({ name: entry.name, error: err });
			console.log('not ok - ' + entry.name);
			console.log('    ' + (err && err.message ? err.message : String(err)));
		}
	}
	console.log('');
	console.log(passed + ' passed, ' + failures.length + ' failed, ' + tests.length + ' total');
	if (failures.length > 0) {
		console.log('');
		for (const failure of failures) {
			console.log('FAIL - ' + failure.name + ': ' + (failure.error && failure.error.message));
		}
		process.exitCode = 1;
	}
}());
