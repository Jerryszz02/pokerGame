# PokerGame

一个使用 Godot 4 和 GDScript 制作的本地单人 Texas Hold'em（德州扑克）原型。玩家可与 1–5 名 AI 对手进行离线牌局；项目不包含账号、联网、真实货币、外部 API、LLM 对手、Steamworks 或第三方扑克库。

## 当前内容

- 完整的德州扑克流程：盲注、翻前、翻牌、转牌、河牌、弃牌、过牌、跟注、加注、全下、摊牌、边池与分池。
- 1–5 名 AI 对手，以及简单、中等、困难三档难度。
- 困难 AI 在翻前使用起手牌评分，翻后使用 Monte Carlo 胜率估算，并结合底池赔率与随机人格参数决策。
- 中文界面：主菜单、牌桌、座位与角色、公共牌、筹码、行动控件、牌局记录、结算面板和设置弹窗。
- 本地设置与战绩：保存 AI 数量、难度、音效/音乐开关，以及总手数、胜手数、净盈利和单手最大收益；可在设置中二次确认后重置统计。
- 已接入程序化生成的牌桌、菜单、角色、卡牌、盲注筹码等 PNG 美术资源；牌面点数与花色仍由运行时文本生成，保证数值准确。

## 环境要求

- Godot 4.7 或兼容的 Godot 4 版本。
- 项目仅使用 GDScript；本机可用 Godot 路径为 `/Applications/Godot_mono.app/Contents/MacOS/Godot`。
- 若使用该 Mono 版 Godot，在新的 shell 中先配置 .NET 8：

```sh
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"
```

## 运行

在 Godot Project Manager 中选择 **Import**，导入：

```text
/Users/jerryszz/Desktop/Projects/pokerGame/project.godot
```

主场景为 `res://scenes/main.tscn`。也可以在项目根目录运行：

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --path .
```

进入游戏后，选择 AI 数量和难度，再点击“开始牌局”。设置按钮可调整本地音效/音乐并查看或重置统计数据。

## 测试

在项目根目录执行。若当前 shell 尚未加载 .NET 环境变量，请先按上节配置。

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s tests/test_runner.gd
```

预期输出：`All poker tests passed.`

该测试覆盖牌组唯一性、牌型与踢脚比较、下注合法性、边池/分池、中文结果与事件记录、本地设置持久化、AI 人格和合法行动，以及 Monte Carlo 胜率边界。

验证常见桌面分辨率下的主界面与设置弹窗布局：

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s tests/ui_layout_probe.gd
```

预期输出：`All UI layout probes passed.`

快速检查主场景能否启动：

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --path . --quit-after 2
```

## 项目结构

```text
scenes/main.tscn        主场景
scripts/game/           牌组、牌型评估、下注流程、边池、摊牌与本地配置
scripts/ai/             起手牌评分、Monte Carlo、人格与 AI 决策
scripts/ui/             Godot Control 界面与本地音效
assets/art/generated/   当前接入的生成式 PNG 美术资源
tests/                  规则回归与 UI 布局探针
docs/                   架构、运行手册与后续规划
```

开发时请保持分层：UI 只能展示状态并提交玩家输入；人类与 AI 的所有行动都必须通过 `PokerRound.apply_action()`；摊牌比较必须通过 `HandEvaluator.evaluate()`。

## 美术资源说明

`assets/art/generated/` 保存当前美术资源及其来源图。无 `-source` 后缀的是选定或候选最终 PNG，实际运行时依赖以 `scripts/ui/main.gd` 中的 `preload()` 为准；`*-source.png` 用于保留原始生成结果。资源清单和后续清理事项见 [assets/art/generated/README.md](assets/art/generated/README.md)。

## 文档

- [架构说明](docs/architecture.md)：游戏规则、AI、UI 的职责和运行流程。
- [运行手册](docs/runbook.md)：本机环境、手动冒烟检查与导出准备。
- [规划文档](docs/planning/README.md)：现有原型的产品、技术与测试约束。
