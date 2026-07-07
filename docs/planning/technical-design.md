# PokerGame 技术设计

## 文档目的

本文把当前仓库证据整理成后续实现必须遵守的技术边界。目标是让开发者在修改规则、AI 或 UI 前，先理解状态归属、控制流和不可破坏的约束。

本文仅根据当前仓库可见内容整理；没有证据的 API、数据库、发布流程和外部依赖不做假设。

## 适用范围

适用：

- `scripts/game/` 内的牌、牌组、手牌评估、下注、边池和牌局生命周期。
- `scripts/ai/` 内的起手牌评分、Monte Carlo、个性配置和行动选择。
- `scripts/ui/main.gd` 内的菜单、牌桌渲染、玩家输入和结果面板。
- `tests/test_runner.gd` 内的当前自动化回归方式。

不适用：

- Godot 导出 preset、Steamworks、iOS 签名、账号系统、数据库、联网协议或服务端架构。

## Plan 或项目证据

| 来源 | 技术结论 |
| --- | --- |
| `AGENTS.md` | 规则、AI、UI 分层是项目约束；行动必须通过 `PokerRound.apply_action()`；摊牌必须通过 `HandEvaluator.evaluate()`。 |
| `docs/architecture.md` | 现有运行流程已明确从 UI 到规则引擎再到 AI/结算的控制流。 |
| `project.godot` | 主场景是 `res://scenes/main.tscn`，项目目标 Godot 4.7，窗口为 1280x720。 |
| `scripts/game/poker_round.gd` | `PokerRound` 是权威状态机，拥有玩家、公共牌、底池、阶段、当前行动者、赢家和边池。 |
| `scripts/ai/ai_decision.gd` | AI 只生成行动字典，依赖 `game.get_legal_actions()`、权益估计和底池赔率。 |
| `scripts/ui/main.gd` | UI 程序化创建节点，玩家按钮调用 `_on_action()` 后重新渲染牌桌。 |
| `tests/test_runner.gd` | 当前验证方式是 Godot headless 运行脚本测试。 |

## 关键决策

| 决策 | 理由 | 后果 |
| --- | --- | --- |
| 使用 Godot 4 + GDScript | 当前项目文件和脚本均为 Godot/GDScript；仓库规则明确不引入 C#。 | 后续逻辑应继续用 GDScript，避免增加 Mono/C# 项目复杂度。 |
| 保持本地离线 | README 和架构文档明确 v1 无 API、LLM、联网、账号、Steamworks。 | 不需要 API、数据库、安全凭据或遥测设计；新增外部调用必须先得到明确需求。 |
| `PokerRound` 作为唯一规则入口 | 下注合法性、阶段推进、筹码和底池必须集中校验。 | UI 和 AI 不能直接改写扑克状态。 |
| `HandEvaluator` 作为摊牌入口 | 手牌比较需要统一排序和 kicker 逻辑。 | 不允许在 UI 或 AI 中重新实现摊牌比较。 |
| Hard AI 保持“确定形态 + 随机选择” | AGENTS 规定 preflop 用 `StartingHandTable`，postflop 用 `MonteCarlo`，个性来自 `PersonalityProfiles`。 | 可以调参，但不应绕开这些组成部分。 |

## 子系统边界

| 子系统 | 目录或文件 | 拥有内容 | 不应拥有 |
| --- | --- | --- | --- |
| 游戏规则 | `scripts/game/` | 牌、牌组、手牌评估、桌面常量、玩家状态、下注轮、边池、摊牌、手牌生命周期。 | UI 节点、按钮文字、AI 风格选择。 |
| AI | `scripts/ai/` | 起手牌评分、Monte Carlo 权益、个性参数、行动选择。 | 直接扣筹码、推进街道、结算底池。 |
| UI | `scripts/ui/main.gd` | 菜单、牌桌布局、玩家输入、状态展示、结果面板。 | 手牌比较、行动合法性、筹码结算。 |
| 测试 | `tests/test_runner.gd` | 规则和 AI 的回归验证。 | 产品运行时逻辑。 |

## 状态和控制流

1. `main.gd` 在 `_ready()` 显示菜单。
2. 玩家选择 AI 数量和难度后，UI 调用 `PokerRound.start_new_match(ai_count, difficulty)`。
3. `PokerRound.start_next_hand()` 重置手牌状态、洗牌、发手牌、收盲注、设置当前行动者。
4. 人类回合时，UI 读取 `get_legal_actions(0)` 并只展示合法行动。
5. 玩家点击按钮后，UI 调用 `PokerRound.apply_action(action_type, amount)`。
6. AI 回合时，`AiDecision.decide(game, player_index)` 读取规则状态并返回行动。
7. AI 返回值仍传入 `PokerRound.apply_action()`。
8. `PokerRound` 在每次行动后推进下注轮、公共牌、无人争夺结算或摊牌。
9. `HandEvaluator` 在摊牌时评估每名仍有资格玩家的最佳五张牌。
10. UI 重新渲染当前状态或结果面板。

## 错误处理和 fallback

- 非当前行动者、已结束手牌、非 active 玩家或非法行动必须返回 `false`，不应部分修改状态。
- `get_legal_actions()` 对无效玩家索引或非 active 玩家返回空行动。
- AI 如果拿到空行动列表，当前实现返回 check 形状；后续如调整，仍必须让规则引擎最终校验。
- .NET 只属于本机 Mono Godot 运行条件；项目代码不应因此引入 C#。

## 兼容性约束

- 保持 `project.godot` 的 `run/main_scene="res://scenes/main.tscn"`，除非同步更新 README、runbook 和验证方式。
- 保持 `tests/test_runner.gd` 可由 Godot headless 直接运行。
- 保持 `assets/icon.svg` 或同步更新 `project.godot` 图标引用。
- 如移动端或 Steam 成为目标，需要先补 release plan 和可能的 UI/输入设计；当前文档不假设这些目标已确认。

## 任务拆分指引

| 改动类型 | 推荐入口 | 必要检查 |
| --- | --- | --- |
| 修牌型或 kicker bug | `scripts/game/hand_evaluator.gd` | 增加或更新手牌比较测试。 |
| 修下注、all-in、边池或阶段推进 | `scripts/game/poker_round.gd` | 增加行动流、边池或分池测试。 |
| 调 AI 风格或难度 | `scripts/ai/` | 确认返回行动总是合法，并补充边界测试或人工牌局烟测。 |
| 改 UI 布局或按钮 | `scripts/ui/main.gd` | 确认 UI 仍只调用规则入口，不直接改扑克状态。 |
| 改运行入口或项目配置 | `project.godot`、`scenes/main.tscn` | 同步 README、runbook 和测试命令。 |

## 非目标

- 不设计服务端、数据库、API、账号、支付或遥测。
- 不重写现有架构文档。
- 不将当前程序化 UI 扩展为完整视觉设计规范。
- 不定义发布路线图或导出签名步骤。

## 实现指引

- 小改动优先局部修改，不做跨目录重构。
- 新规则先在 `scripts/game/` 完成权威状态和测试，再让 UI 展示。
- 新 AI 行为只应读取公开规则状态或规则层提供的方法，避免依赖 UI 节点。
- 新 UI 控件只展示状态或提交行动，不直接维护第二份牌局状态。
- 任何新增随机性都应可通过边界测试验证输出形状和合法性。

## 验收标准

- Godot headless 测试通过。
- 主要人工流程可从菜单开始并完成一手牌。
- 规则、AI、UI 的职责边界没有被打破。
- README、runbook 或 planning 文档在入口、命令或行为改变时同步更新。

## 待确认

| 问题 | 影响 |
| --- | --- |
| 是否需要把程序化 UI 拆成 `.tscn` 子场景 | 会改变 UI 维护方式和测试重点。 |
| Monte Carlo 性能预算 | 会影响 hard AI 的 simulation_count、响应时间和未来平台适配。 |
| 是否需要可重复随机种子 | 会影响测试稳定性、AI 调试和可复现 bug 报告。 |
| 是否需要存档或设置持久化 | 会引入数据设计和迁移问题。 |
| 是否切换到非 Mono Godot | 当前本机用 Mono app 运行；项目本身不使用 C#，但工具链选择会影响本地验证说明。 |
