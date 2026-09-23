# itch.io Web build and release

This document describes the Godot Web export added for itch.io play-in-browser.
As of 2026-09-23, **itch.io publishes v1.4.0** through the `web`, `windows-x64`, and `macos-universal` Butler channels:
<https://jerryszz02.itch.io/poker-game>. See [release delivery and verification](releases/1.4.0.md). GitHub Releases retains v1.2.0.
Browser audio and local persistence are implemented. The code waits for an input
event to start Web audio, and saves use Godot's browser-local storage.

The build tooling itself produces packages, not uploads. Existing records include
successful local export/ZIP validation and a user local preview without reported
issues. This documentation pass did not replay the complete audio/persistence or
browser/OS matrix. The checklist below is a reusable verification procedure, not a
claim that these features or the public embed are missing.

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
python3 -m pip install -r tools/requirements-web.txt
# Install FFmpeg with your package manager (apt-get install ffmpeg / brew install ffmpeg).
python3 tools/build_release.py --godot "$GODOT_BIN" --target web
```

If FFmpeg is not on PATH, pass `--ffmpeg /absolute/path/to/ffmpeg`. Web builds stage
an isolated project, generate a static weight-400 font with all 30,890 character
mappings retained, and transcode the complete music track from 320 to 96 kbps.
Original assets and desktop builds are unchanged. The manifest records before/after
asset sizes. FontTools and FFmpeg are build dependencies only; no browser downloads
or runtime third-party services are added.

The Web preset uses `tools/web_shell.html` for bilingual download progress,
startup status, connection errors and a same-page Retry button. A 20-second lack
of progress shows a nonfatal warning; it does not cancel a slow download. Retry
reloads only the game frame and does not clear local saves. Test the loader with
`node tools/test_web_loader.js`.

On 2026-09-20, the published v1.3.0 frame still served 44,051,552 bytes of PCK
and 38,820,072 bytes of WASM before HTTP decoding. Its gzip transfers were
41,132,840 and 10,643,501 bytes respectively. Chrome showed
`ERR_CONNECTION_CLOSED` for both while the default splash remained visible.
Two simultaneous bounded downloads measured about 119 KB/s (PCK) and 66 KB/s
(WASM), timing out at 55 seconds. These measurements identify a slow/failing
download path on the tested connection, not a universal itch.io speed or an AI
startup stall. Gzip and isolation headers were already present. Smaller assets
and loader recovery need a fresh public-frame check after deployment; local
verification alone does not establish that CDN delivery has recovered.

The first local optimized candidate reduced the Web ZIP from 52,146,416 to
38,846,693 bytes (25.5%) and the uncompressed PCK from 44,051,552 to 29,754,624
bytes. WASM was unchanged. Godot import, audio and bilingual UI probes passed;
Chrome reached the Chinese main menu. A local server returning HTTP 503 for
`index.pck` produced the new connection error/Retry view, and after restoring
the file, clicking Retry reached the menu. This is local candidate evidence;
the public itch.io frame has not been replaced by this change.

Build (or rebuild) the desktop candidates with the same script:

```sh
python3 tools/build_release.py --godot "$GODOT_BIN" --target windows
python3 tools/build_release.py --godot "$GODOT_BIN" --target macos
```

A clean checkout is required for a release build. For an explicitly unverified
local package add `--candidate`; the manifest records the actual checkout state.
Version 1.4.0 is published through stable Butler channels on itch.io. Preserve
previous release packages locally; a channel push replaces its current download.
The user tried the local preview without reported issues on 2026-09-11. The public
itch.io embed and v1.2.0 downloads were subsequently confirmed from the page.

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

## Upload with the official Butler CLI

`tools/upload_itch.py` is a local preflight wrapper around the official Butler
client. It reads the `export/packages/` manifests produced by
`tools/build_release.py`, re-validates every selected package, and only then runs
`butler push ... --userversion ...`. Uploads to existing channels may become live
immediately. Butler authenticates through
its normal local login or the `BUTLER_API_KEY` environment variable. The script
accepts no secret flags and inherits the environment unchanged.

Install Butler and log in once, following the official documentation:

- Installing: <https://itch.io/docs/butler/installing.html>
- Login and API keys: <https://itch.io/docs/butler/login.html>
- Push reference, including `--userversion` and `--hidden`:
  <https://itch.io/docs/butler/pushing.html>

```sh
butler login
butler version
```

Build from a clean checkout, then dry-run the upload. Packages made with
`--candidate` from a dirty checkout are rejected. For the first migration, create
hidden channels for review:

```sh
python3 tools/build_release.py --godot "$GODOT_BIN" --target web
python3 tools/build_release.py --godot "$GODOT_BIN" --target windows
python3 tools/build_release.py --godot "$GODOT_BIN" --target macos

python3 tools/upload_itch.py --target all --hidden --dry-run
python3 tools/upload_itch.py --target all --hidden
```

`--dry-run` performs the full local validation and prints the exact Butler argv
without invoking Butler, so it needs no installation, login, network access, or
API key. A real run stops at the first non-zero Butler exit and exits non-zero.
The default `--packages-dir` is `export/packages`, the default `--project` is
`jerryszz02/poker-game`, and the default `--butler` is `butler` on `PATH`.

| `--target` | Channel | Manifest | Uploaded file |
| --- | --- | --- | --- |
| `web` | `web` | `web-manifest.json` | `PokerGame-<version>-web.zip` |
| `windows` | `windows-x64` | `windows-x64-manifest.json` | `PokerGame-<version>-windows-x64.zip` |
| `macos` | `macos-universal` | `macos-universal-manifest.json` | `PokerGame-<version>-macos-universal.zip` |

Preflight requires each selected manifest to be a JSON object with the expected
target, `dirty` exactly `false`, a sensible version, a full Git SHA in `commit`,
a filename of exactly `PokerGame-<version>-<target-label>.zip` inside the
packages directory, and a byte size and SHA-256 that match the file on disk. The
package path is rejected if a symlink resolves outside the packages directory.
With `--target all`, the three manifests must agree on one version and one
source commit; `--expected-commit <sha>` pins the commit explicitly. Web ZIPs are
re-opened with the same `validate_web_archive` check the build uses, so
`index.html` and the game files must be at the root, with licenses under `licenses/`.
A `public_release_ready: false` manifest is intentionally ignored and left
unchanged: an upload is a candidate upload, not full public runtime verification.

### New channels, `--hidden`, and updates

`--hidden` forwards Butler's official `--hidden` flag, which creates a **new**
channel that is not shown on the project page. Official Butler accepts `--hidden`
only when the channel does not exist yet and errors for an existing channel, so
it cannot be used to stage an update on a channel that is already live. For the
first migration, create the new channel hidden, upload, and verify it before
exposing it. Keep the existing manually uploaded files in place and unchanged
until the new channel passes the checklist below; do not remove them earlier.

A normal push to an **existing** channel updates that channel and can become
visible to players as soon as the upload completes, while patch optimization
continues in the background. For later updates, omit `--hidden` from the commands
above after reviewing the packages and intended live update.

### Verify the recorded build and the public page

After a push, confirm what itch.io recorded with Butler, then run the real public
checks:

```sh
butler status jerryszz02/poker-game:web
butler status jerryszz02/poker-game:windows-x64
butler status jerryszz02/poker-game:macos-universal
```

`butler status` only reports the build itch.io registered. Actual public checks
still mean loading <https://jerryszz02.itch.io/poker-game> in a browser,
confirming the embed boots inside the itch.io frame, and downloading each build.
Butler treats the input ZIP as a directory and repackages downloads, so the
downloaded ZIP's SHA-256 can differ from the local input ZIP. Compare extracted
file contents with the validated local package; keep local ZIP checksums as
build-input evidence.

For a **new** Web channel, two itch.io page settings are chosen once, when the
channel is first configured: the HTML file must be marked "This file will be
played in the browser" so `index.html` is the entry point, and the
**SharedArrayBuffer support** frame option must be enabled so the threaded
export receives cross-origin isolation headers. Both settings persist for later
pushes to the same channel.

### GitHub Actions upload

The repository's existing Desktop release checks workflow (`workflow_dispatch`)
has two optional boolean inputs: `upload_to_itch` (default
`false`) and `itch_hidden` (default `true`, for the first hidden-channel
migration). Add `BUTLER_API_KEY` as a repository Actions secret, then run the
workflow on `main` with `upload_to_itch` enabled. For subsequent updates to
existing channels, disable `itch_hidden`.

The upload job waits for rules, desktop, and web jobs to succeed, downloads the
three artifacts from that same run, and checks every manifest against the run's
commit before uploading. Ordinary `push` and `pull_request` builds do not upload.
Upload runs queue separately, so a later code push does not cancel an upload
between channels. The workflow installs official Butler 15.31.0 and prints
`butler status` after uploading; public verification remains a separate step.

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

## Manual itch.io dashboard procedure

The Butler CLI above is the preferred path for package uploads. Use this manual
dashboard procedure for steps the CLI does not cover, such as the one-time HTML
playable and SharedArrayBuffer settings, or when a fully manual upload is wanted.

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
   separate, approved publishing step says otherwise. Building alone does not
   upload; the CLI or optional Actions upload must be invoked explicitly.
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
| Windows/macOS download buttons work | Download, compare extracted contents with the local package (ZIP SHA-256 only for unchanged manual uploads), and launch | ☐ | ☐ | ☐ |

Known limits to keep in the page copy: browser compatibility depends on WebGL 2.0 and SharedArrayBuffer;
the 1.2.0 source includes English / Simplified Chinese and local table audio; IndexedDB storage
is local to one browser/device/origin; and desktop signing statements still apply to
the downloadable builds, not to the Web build.
