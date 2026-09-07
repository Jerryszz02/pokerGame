# PokerGame

中文离线单人德州扑克。选择 1–5 个 AI 对手和三档难度，在像素牌桌上完成下注、全下、摊牌和边池结算。目标是赢得所有筹码；玩家出局时显示比赛总结。

游戏没有账号、联网、真实货币、外部 API 或遥测。设置和已完成手牌的聚合战绩保存在本机；当前对局不保存，离开时会提示。菜单和设置内提供玩法说明、音效与行动节奏设置。

## 首发状态

正在进行稳定桌面首发验收，当前候选包不能视为全部验收完成。公开下载入口会在目标系统验证和试玩完成后更新。[首发验收标准](docs/planning/release-plan.md)明确区分代码检查、独立安装包、真实试玩和公开发布。

[玩家说明](docs/player-guide.md)介绍操作、数据位置和反馈方式。字体、引擎及美术来源见 [第三方说明](THIRD_PARTY_NOTICES.md)。

## 从源码运行

项目仅使用 Godot 4 + GDScript。正式构建固定使用 Godot 4.7.2 标准版；不需要 .NET。安装固定引擎并启动（macOS/Linux）：

```sh
GODOT_BIN="$(python3 tools/bootstrap_godot.py)"
"$GODOT_BIN" --path .
```

也可以在 Godot 4.7.2 中导入 `project.godot`，运行 `scenes/main.tscn`。

```sh
python3 tools/verify.py --godot "$GODOT_BIN"
```

构建、窗口检查、长测及平台验收见 [运行手册](docs/runbook.md)。模块职责见 [架构说明](docs/architecture.md)，需求和验收基线见 [规划入口](docs/planning/README.md)。
