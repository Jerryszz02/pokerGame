# itch.io Web build and release

This document describes the Godot Web export added for itch.io play-in-browser.
The build tooling produces a **candidate**: local Godot 4.7.2 Web export and ZIP
validation passed on 2026-09-11. Browser gameplay, persistence, and the itch.io
iframe have not been validated; no upload was performed. The public page
<https://jerryszz02.itch.io/poker-game> currently uses external GitHub download
links, as recorded in [storefront/README.md](storefront/README.md); nothing here
moves, replaces, or publishes those files. Treat every result below as unverified
until it is recorded with a commit, package hash, browser/OS versions, and date.

Web support does not change game rules, AI, audio behavior, or save data formats.
The only product change is the target-specific renderer override
`renderer/rendering_method.web="gl_compatibility"`; desktop keeps
`renderer/rendering_method="mobile"`.

## Build commands

Install the pinned editor and its templates (desktop plus the threaded Web pair):

```sh
GODOT_BIN="$(python3 tools/bootstrap_godot.py --templates)"
"$GODOT_BIN" --version
```

Build the Web candidate ZIP:

```sh
python3 tools/build_release.py --godot "$GODOT_BIN" --target web
```

Build (or rebuild) the desktop candidates with the same script:

```sh
python3 tools/build_release.py --godot "$GODOT_BIN" --target windows
python3 tools/build_release.py --godot "$GODOT_BIN" --target macos
```

A clean checkout is required for a release build. For an explicitly unverified
local package add `--candidate`; the manifest records the actual checkout state.
The current version remains 1.1.0 for local candidates. Assign a new release
version before publishing these changes; do not overwrite the existing 1.1.0 release.

Outputs land in `export/packages/`:

| Target | ZIP | Manifest |
| --- | --- | --- |
| Web | `PokerGame-<version>-web.zip` | `web-manifest.json` |
| Windows x64 | `PokerGame-<version>-windows-x64.zip` | `windows-x64-manifest.json` |
| macOS Universal | `PokerGame-<version>-macos-universal.zip` | `macos-universal-manifest.json` |

The Web ZIP keeps `index.html` at the archive root followed by the exported
`index.js`, `index.wasm`, `index.pck`, `index.audio.worklet.js`,
`index.audio.position.worklet.js`, the generated icon, and the license files. The
build script re-opens the finished ZIP and fails if any required member or license
is missing. The 1 MiB completeness gate applies to the WebAssembly payload, not to
`index.html`, which is expected to be small.

The Web preset uses the threaded template pair (`web_debug.zip` / `web_release.zip`)
because `variant/thread_support=true` and `variant/extensions_support=false`
(option names confirmed against the pinned 4.7.2 editor in the local cache; the
threaded template is the one whose JavaScript contains the `pthread` code). With
thread support on, 4.7.2 reuses `index.js` as the worker script and emits no
separate `index.worker.js`; the build validator tolerates that optional file if a
future engine adds it. Progressive Web App output is disabled
(`progressive_web_app/enabled=false`); the
page relies on itch.io's native cross-origin isolation headers instead of the Godot
service worker. The manifest deliberately reports
`web_native_self_test: not established by this script` and
`browser_validation: not established by this script`, and it never claims macOS
signing for the Web target.

## Local preview

Extract the Web ZIP and serve the directory over loopback with the isolation
headers a threaded build needs:

```sh
mkdir -p /tmp/pokergame-web && unzip -o export/packages/PokerGame-<version>-web.zip -d /tmp/pokergame-web
python3 tools/serve_web.py --directory /tmp/pokergame-web --port 8060
```

Then open <http://127.0.0.1:8060/>. The server binds `127.0.0.1` only and sends
`Cross-Origin-Opener-Policy: same-origin`,
`Cross-Origin-Embedder-Policy: require-corp`, and
`Cross-Origin-Resource-Policy: cross-origin`, so `crossOriginIsolated` should be
`true` and `SharedArrayBuffer` available. It uses only the Python standard library:
no telemetry, plugins, or external requests.

## Browser storage and saves

Godot `user://` maps to browser storage. On the Web export that is IndexedDB,
scoped by the browser profile and the page origin (scheme + host + port). It is
**not** a global account store:

- Saves are visible only in the same browser, on the same device, and on the same
  origin. A different browser, private/incognito window, or another origin starts
  empty.
- Clearing site data, using private mode, or blocking IndexedDB/storage removes or
  prevents access to saves. The game's existing save-failure messaging and retry
  behavior is unchanged.
- No itch.io cloud-save or sync API is documented in the itch.io serverside API
  reference, so this build does not use one. itch.io does not sync `user://` data
  between devices.
- The itch.io "SharedArrayBuffer support" option can serve the game from a
  different hostname (a different origin) than a non-isolated upload. Because
  IndexedDB is origin-scoped, toggling that option can separate existing saves from
  new ones.

The existing desktop save semantics are preserved: `user://poker_profile.cfg`
stores preferences; `user://poker_practice/profile.json` and `hand_<id>.json` store
tutorial progress, achievements, statistics and completed-hand replays. An
unfinished hand or match cannot be resumed after refreshing or closing the game.
Settings have a 0.3-second debounce, and browser persistence is asynchronous;
closing a tab immediately after an update is not a verified save guarantee.
This change adds no new save feature, migration, or cross-device sync.

References checked on 2026-09-11: [Godot Web persistence](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#using-cookies-for-data-persistence),
[itch.io APIs](https://itch.io/docs/api/overview), and
[itch.io SharedArrayBuffer and origin changes](https://itch.io/t/2025776/experimental-sharedarraybuffer-support).

## itch.io upload steps (candidate, not executed)

1. Open the project edit page: <https://itch.io/game/edit/4983610>.
2. **HTML play-in-browser build:** upload `PokerGame-<version>-web.zip` as an HTML
   game and choose "This file will be played in the browser". Keep `index.html` at
   the ZIP root. Under **Embed options → Frame options**, enable the
   **SharedArrayBuffer support** checkbox so itch.io serves the cross-origin isolation headers; the threaded
   export will otherwise fail to start. Confirm the game's iframe and embed URL
   serve the new build.
3. **Downloadable builds:** upload `PokerGame-<version>-windows-x64.zip` and
   `PokerGame-<version>-macos-universal.zip` as ordinary downloadable files on the
   same page. Keep the existing Windows/macOS install copy accurate: Windows builds
   are unsigned, macOS builds are ad-hoc signed and not notarized.
4. Keep the current public page, price, visibility, and release files unless a
   separate, approved publishing step says otherwise. This repository does not
   publish or upload for you.
5. If the page previously linked to GitHub only, do not remove those links until the
   uploaded HTML build and download files pass the checklist below.

## Manual acceptance checklist

Record each item as **candidate**, **verified**, or **published**. A candidate build
is not evidence. "Verified" requires a named commit, the package SHA-256, the exact
browser and OS versions, and the date; "published" requires a re-check against the
public page after itch.io processes the upload. Do not mark anything verified from
CI alone.

| Check | How | Candidate | Verified | Published |
| --- | --- | --- | --- | --- |
| `crossOriginIsolated` is `true` | Browser console on the served page | ☐ | ☐ | ☐ |
| `SharedArrayBuffer` is available | Browser console (`typeof SharedArrayBuffer`) | ☐ | ☐ | ☐ |
| Game boots and renders the table | Play a visible hand | ☐ | ☐ | ☐ |
| Real hard-AI turns complete | Play at least one full hand vs. hard AI; observe a genuine AI raise/fold, not a stall | ☐ | ☐ | ☐ |
| Audio after a user gesture | Start music/SFX after clicking; confirm no autoplay block error | ☐ | ☐ | ☐ |
| Settings persist across refresh | Change language/volume, refresh, reopen Settings | ☐ | ☐ | ☐ |
| Tutorial progress persists | Complete a lesson, refresh, reopen the tutorial list | ☐ | ☐ | ☐ |
| Stats and replays persist | Play a hand, refresh, open records/history and replay it | ☐ | ☐ | ☐ |
| Actual itch iframe works | Load the itch.io game page (not the local server) and repeat the checks above inside the embed | ☐ | ☐ | ☐ |
| Windows/macOS download buttons work | Download each ZIP from the page, verify SHA-256, extract and launch | ☐ | ☐ | ☐ |

Known limits to keep in the page copy: the Web build is a new, unverified target;
the interface language and existing gameplay text are unchanged; IndexedDB storage
is local to one browser/device/origin; and desktop signing statements still apply to
the downloadable builds, not to the Web build.
