**English** · [简体中文](README.zh-CN.md)

![PokerGame — Offline Texas Hold’em](docs/media/pokergame-banner.png)

# Your seat at the table is always open.

A free, offline Texas Hold’em game for Windows and macOS. Sit down with up to five AI opponents, read the table, and decide when to fold, call, or put your whole stack on the line.

**[Download on itch.io](https://jerryszz02.itch.io/poker-game)** · **[Download from GitHub](https://github.com/Jerryszz02/pokerGame/releases/latest)**

**Single player · 1–5 AI opponents · Three difficulty levels · Simplified Chinese interface**

The published **v1.1.0** downloads use Simplified Chinese. The current source adds **English / 简体中文** switching in Settings, lounge background music, and recorded card/chip sounds. These changes require a new release before they appear in public downloads. See the [implementation and checks](docs/planning/bilingual-audio-plan.md).

![A river decision against five AI opponents, with fold, call, and all-in actions](docs/media/river-decision.png)

*The river is out. The next move is yours. Actual gameplay; the interface is in Chinese.*

## Play the table your way

- **Choose your company.** Play heads-up or fill the table with five AI opponents. Pick Easy, Medium, or Hard before you start.
- **Watch how they bet.** On Hard, opponents have different betting tendencies, from cautious players to aggressive raisers and persistent callers.
- **Win the last chip.** Everyone starts with 1,000 chips and fixed 10/20 blinds. Keep playing hands until you own the table—or your stack runs out.
- **Set your own pace.** Switch between normal and fast actions, pause when you need a break, and check the current hand’s action log.
- **Keep it local.** No game account, internet connection, real-money wagering, or background data collection. Your settings and completed-hand statistics stay on your device.

## From the first bet to the showdown

![The action log shows the current hand’s betting history](docs/media/action-log.png)

*Check who acted and how much they put in with the current hand’s action log.*

![Cards are revealed and the pot is awarded at showdown](docs/media/showdown.png)

*Follow each hand from the blinds to the reveal, including all-ins, side pots, and split pots.*

![The main menu lets you select the number of opponents and difficulty](docs/media/choose-your-table.png)

*A quiet, lamp-lit poker room. Choose your opponents and take a seat.*

## Download and take a seat

Get the desktop ZIP for your system from [itch.io](https://jerryszz02.itch.io/poker-game) or [GitHub Releases](https://github.com/Jerryszz02/pokerGame/releases/latest). You do not need the Godot editor, .NET, or this source repository to play.

| System | Download | Start playing |
| --- | --- | --- |
| Windows x64 | `PokerGame-1.0.0-windows-x64.zip` | Extract the whole ZIP, then open `PokerGame.exe`. |
| macOS | `PokerGame-1.0.0-macos-universal.zip` | Extract the ZIP, then open `PokerGame.app`. |

Use a display area of at least **1280 × 720** and a mouse. The macOS package contains Apple Silicon and Intel binaries; Intel Macs have not been separately validated. Windows builds are unsigned, and macOS builds are not Apple-notarized, so your system may show a first-launch security prompt. See the [release notes and checksums](https://github.com/Jerryszz02/pokerGame/releases/tag/v1.0.0) before opening the download.

**A quick guide to the Chinese buttons:**

| In the game | Meaning |
| --- | --- |
| 开始牌局 / 玩法说明 | Start game / How to play |
| 弃牌 / 让牌 / 跟注 | Fold / Check / Call |
| 加注到 / 全下 | Raise to / All-in |
| 下一手 / 设置 / 记录 | Next hand / Settings / Action log |

**Before you leave a match:** settings and completed-hand statistics are saved, but an unfinished match is not. You can pause while the game is open; returning to the menu or quitting abandons that match.

## Tell us about your game

Found a confusing hand or a bug? [Open an issue](https://github.com/Jerryszz02/pokerGame/issues) with your game version, operating system, opponent count, difficulty, and a screenshot or steps to reproduce. You can also leave feedback on [itch.io](https://jerryszz02.itch.io/poker-game).

The game and this page include AI-generated artwork. Gameplay screenshots show the actual game; the title banner is promotional artwork. See [third-party notices](THIRD_PARTY_NOTICES.md) and [page asset sources](docs/storefront/README.md).

<details>
<summary><strong>For developers: run from source</strong></summary>

Current source adds tutorials, configurable stacks/blinds, saved replays and local statistics/achievements. Practice coaching and radar scores remain unavailable. Downloaded v1.0.0 packages are unchanged; see the [implementation and checks](docs/planning/practice-implementation.md).

Built with Godot 4 and GDScript. Release builds use **Godot 4.7.2 standard**, with no .NET requirement. On macOS/Linux:

```sh
GODOT_BIN="$(python3 tools/bootstrap_godot.py)"
"$GODOT_BIN" --path .
```

Alternatively, import `project.godot` in Godot 4.7.2 and run `scenes/main.tscn`.

```sh
python3 tools/verify.py --godot "$GODOT_BIN"
```

[Player guide (Chinese)](docs/player-guide.md) · [Runbook](docs/runbook.md) · [Architecture](docs/architecture.md) · [Planning and acceptance](docs/planning/README.md)

</details>
