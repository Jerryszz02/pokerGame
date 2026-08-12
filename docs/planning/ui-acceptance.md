# UI 验收指标（ui-acceptance）

本文定义 PokerGame UI 修复的可验收指标。机器指标由 `tests/ui_playthrough_probe.gd`（窗口模式）与 `tests/ui_layout_probe.gd`（headless）自动断言；人工指标由 agent 扮演玩家对截图做对抗式审查。

## 问题分级

- **P0**：信息无法读取或显示错误（文字被裁断、数值看不清、状态表达错误）。
- **P1**：重叠 / 溢出 / 模糊 / 裁切（控件压框、素材非设计重叠、文字超出容器、纹理线性模糊）。
- **P2**：观感不佳（间距失衡、对齐粗糙、对比度偏弱）。记录并尽量修，不阻塞验收。

## A. 机器可检指标（探针断言，失败即非零退出）

- **M1 视口越界**：1280x720 / 1440x900 / 1920x1080 下，菜单、设置弹窗、牌桌各状态（翻前 / 翻后 / 加注 / 全下 / 结算）所有可见 Control 完全位于视口内。
- **M2 文本不溢出**：所有 Label 的字体实测宽度 ≤ 可用宽度；带 `clip_text` 的 Label（名牌、事件日志行）不得发生截断；Button 文字不超出按钮内容区（stylebox content margin 之内）。
- **M3 控件不压框、不互叠**：按钮 / 滑条 / 输入框完全位于所属浮动面板内容区；可见交互控件两两全矩形不相交。关闭的 Log 不占据牌桌布局，打开后的 400px 抽屉不得越界。
- **M4 素材分层白名单**：人物主体与 `TableFeltSafeZone` 重叠面积不超过人物框的 10%；禁止行动标签 / 底牌 / 公共牌 / `PotDisplay` 发生可见碰撞。以命名节点（`Seat{n}Portrait`、`Seat{n}Info`、`Seat{n}Bet`、`Seat{n}HoleCards`、`CommunityCards`、`PotDisplay`）实测矩形断言。
- **M5 渲染清晰**：所有 TextureRect `texture_filter == NEAREST`；按钮和字段的 normal / hover / pressed / disabled / focus 均为 `anti_aliasing == false` 的 `StyleBoxFlat`，各状态保持相同轮廓。中文 caption ≥ 13px，按钮 ≥ 16px，Log 正文 14px、标题 16px。
- **M6 状态与容量**：当前行动者必须有轮廓 shader 和三角标记，不允许矩形人物高亮；角色标记绑定正确座位。筹码贪心分解覆盖 `0、1、5、20、945、1000、6000`，座位最多 2×5，底池最多 3×8，金额文字保持精确。Log 打开时 `_ai_can_advance()` 为 false，关闭后恢复，已读后圆点消失。牌局内设置弹窗提供暂停按钮（菜单内不出现）；暂停时 `_ai_can_advance()` 为 false 并显示 `PauseOverlay` 遮罩，点击继续后恢复。

## B. 人工对抗审查（agent 扮演玩家）

- **M7 点击流零 P0/P1**：完整玩家路径——菜单 → 设置弹窗（含重置两步确认）→ 开局 → 设置弹窗暂停/继续 → Log 开关 → 每街行动（含加注展开、全下）→ 结算 → 下一手 → 重新开始回菜单——逐状态截图（`/tmp/poker_audit/`），逐张以玩家视角审查。验收要求最后一轮 0 个 P0、0 个 P1。
- **M8 回归全绿**：以下三条命令退出码均为 0：

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s tests/test_runner.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s tests/ui_layout_probe.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --path . -s tests/ui_playthrough_probe.gd
```

## 审查流程（每轮迭代）

1. 运行 playthrough 探针，收集机检失败项与 `/tmp/poker_audit/*.png`。
2. 逐张查看截图，按 P0/P1/P2 记录问题清单。
3. 只修改 `scripts/ui/`（必要时含测试节点命名），不碰 `scripts/game/` 与 `scripts/ai/`。
4. 重跑三条测试命令；回到第 1 步，直到 M1-M8 全部满足。
