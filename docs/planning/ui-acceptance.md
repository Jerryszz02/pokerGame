# UI 验收指标（ui-acceptance）

本文定义 PokerGame UI 修复的可验收指标。机器指标由 `tests/ui_playthrough_probe.gd`（窗口模式）与 `tests/ui_layout_probe.gd`（headless）自动断言；人工指标由 agent 扮演玩家对截图做对抗式审查。

## 问题分级

- **P0**：信息无法读取或显示错误（文字被裁断、数值看不清、状态表达错误）。
- **P1**：重叠 / 溢出 / 模糊 / 裁切（控件压框、素材非设计重叠、文字超出容器、纹理线性模糊）。
- **P2**：观感不佳（间距失衡、对齐粗糙、对比度偏弱）。记录并尽量修，不阻塞验收。

## A. 机器可检指标（探针断言，失败即非零退出）

- **M1 视口越界**：1280x720 / 1440x900 / 1920x1080 下，菜单、设置弹窗、牌桌各状态（翻前 / 翻后 / 加注 / 全下 / 结算）所有可见 Control 完全位于视口内。
- **M2 文本不溢出**：所有 Label 的字体实测宽度 ≤ 可用宽度；带 `clip_text` 的 Label（名牌、事件日志行）不得发生截断；Button 文字不超出按钮内容区（stylebox content margin 之内）。
- **M3 控件不压框、不互叠**：按钮 / 滑条 / 输入框完全位于所属面板内容区；所有 `StyleBoxTexture` 面板的 content margin ≥ 其九宫格 texture margin（内容不得画进装饰边框厚度内）；可见交互控件两两全矩形不相交。
- **M4 素材分层白名单**：仅允许设计内重叠——名牌压角色下缘、筹码与角色压桌沿。禁止：行动标签 vs 任意底牌 / 公共牌、筹码 vs 公共牌、座位组件 vs 事件日志与动作面板。以命名节点（`Seat{n}Bet`、`Seat{n}HoleCards`、`CommunityCards`、`PotLabel` 等）实测矩形断言。
- **M5 渲染清晰**：所有 TextureRect 与贴图按钮 `texture_filter == NEAREST`；按钮 / 字段 nine-slice 边距与源图切片一致（沿用 `ui_layout_probe.gd` 现有断言）。

## B. 人工对抗审查（agent 扮演玩家）

- **M6 点击流零 P0/P1**：完整玩家路径——菜单 → 设置弹窗（含重置两步确认）→ 开局 → 每街行动（含加注滑条、全下）→ 结算 → 下一手 → 重新开始回菜单——逐状态截图（`/tmp/poker_audit/`），逐张以玩家视角审查。验收要求最后一轮 0 个 P0、0 个 P1。
- **M7 回归全绿**：以下三条命令退出码均为 0：

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s tests/test_runner.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s tests/ui_layout_probe.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --path . -s tests/ui_playthrough_probe.gd
```

## 审查流程（每轮迭代）

1. 运行 playthrough 探针，收集机检失败项与 `/tmp/poker_audit/*.png`。
2. 逐张查看截图，按 P0/P1/P2 记录问题清单。
3. 只修改 `scripts/ui/`（必要时含测试节点命名），不碰 `scripts/game/` 与 `scripts/ai/`。
4. 重跑三条测试命令；回到第 1 步，直到 M1-M7 全部满足。
