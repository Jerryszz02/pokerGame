# PokerGame 项目规划文档

## 文档目的

本目录是 PokerGame 后续开发前的 planning 入口。它不是代码说明书的替代品，而是把当前仓库已经能证明的产品行为、实现边界和验收方式整理成可维护的开发依据。

本次生成属于现有项目梳理模式：仅根据当前仓库可见内容整理；未在仓库中找到证据的功能、用户、架构、API、数据库、部署目标、时间线和负责人均不做假设。

## 生成信息

| 项目 | 内容 |
| --- | --- |
| 请求 | 根据当前 Godot 扑克项目进度同步 `docs/` 项目文档 |
| 生成时间 | 2026-07-01；同步时间 2026-07-16 |
| 项目根目录 | `/Users/jerryszz/Desktop/Projects/pokerGame` |
| 项目类型 | Godot 4 + GDScript 本地单人 Texas Hold'em 原型 |

## 已检查的项目证据

| 证据 | 用途 |
| --- | --- |
| `README.md` | 确认项目目标、当前功能、运行方式、测试命令和离线约束。 |
| `AGENTS.md` | 确认开发规则：Godot 4 + GDScript、禁止未请求的 C#/外部 API/LLM/插件、规则/AI/UI 分层。 |
| `docs/architecture.md` | 确认现有运行流程、游戏层、AI 层、UI 层和测试覆盖。 |
| `docs/runbook.md` | 确认本地 Godot/.NET 状态、运行命令、测试命令和导出准备限制。 |
| `project.godot` | 确认项目名称、主场景、窗口尺寸、图标和 Godot 4.7 配置。 |
| `scenes/main.tscn`、`scripts/ui/main.gd` | 确认主 UI 入口、菜单、桌面、行动按钮和结果面板。 |
| `scripts/game/local_profile.gd` | 确认本地设置、聚合战绩、默认值和 `user://poker_profile.cfg` 持久化边界。 |
| `scripts/game/*.gd` | 确认牌组、手牌评估、桌面状态、下注流程、边池、摊牌和行动合法性。 |
| `scripts/ai/*.gd` | 确认简单/中等/困难 AI 的决策来源、Monte Carlo 和个性配置。 |
| `assets/art/generated/README.md`、`style/style-guide.png`、生成 Prompt | 确认当前像素美术方向、资源清单、来源文件约定和运行时清理要求。 |
| `tests/test_runner.gd`、`tests/ui_layout_probe.gd` | 确认当前规则/AI/本地配置回归和 UI 布局、资源接入探针。 |

## 项目概览

PokerGame 是一个本地运行的 Texas Hold'em 单人原型。玩家在中文 Godot UI 中选择 1-5 个 AI 对手和 AI 难度后开始牌局。每手牌由规则引擎发牌、收盲注、处理下注轮、推进公共牌阶段，并在无人跟注或摊牌时结算筹码。当前界面已经接入深夜地下牌局主题的生成式像素美术，并提供真实事件日志、设置弹窗、本地音效开关和聚合战绩。

当前项目刻意保持离线：没有账号、联网、真实货币、外部 API、LLM 对手、Steamworks 集成或第三方扑克库。后续开发应先保持这个边界，除非用户明确要求扩展。

核心协作方式：

1. UI 层只收集玩家输入并展示状态。
2. AI 层只产出候选行动。
3. 所有人类和 AI 行动都必须进入 `PokerRound.apply_action()`。
4. 规则引擎统一检查行动是否合法、更新下注状态、推进牌局和结算。
5. 摊牌比较必须使用 `HandEvaluator.evaluate()`。
6. 本地设置和聚合战绩由 `LocalProfile` 通过 Godot `ConfigFile` 保存；它不属于扑克规则状态。
7. 运行时 UI 组合生成式 PNG 与动态中文文字；牌值、数值和事件不得固化进图片。

## 已生成或已更新文档

| 文档 | 用途 |
| --- | --- |
| `docs/planning/prd.md` | 定义当前原型必须保留的用户可见行为、功能边界和非功能要求。 |
| `docs/planning/technical-design.md` | 定义后续实现必须遵守的模块边界、状态流、关键约束和任务拆分方式。 |
| `docs/planning/test-plan.md` | 定义当前最小自动化与人工验收方式，以及测试未覆盖风险。 |
| `docs/art-direction.md` | 定义当前像素美术色板、硬边表现、动态内容边界和资产维护基线。 |
| `docs/architecture.md` | 同步当前规则、AI、UI、美术、本地配置和测试边界。 |
| `docs/runbook.md` | 同步当前本机环境、验证命令、人工烟测、本地数据和资源维护流程。 |

## 已跳过目录文档

| 文档 | 跳过原因 |
| --- | --- |
| `project-brief.md` | 项目背景、目标用户、范围和非目标已合并到本索引与 `prd.md`，单独成篇会重复。 |
| `architecture.md` | 仓库已有 `docs/architecture.md` 覆盖模块职责和运行流程，planning 中只保留技术约束，不重复生成。 |
| `user-flow.md` | 当前用户流程可以放进 `prd.md` 的功能需求和验收场景，单独文档会重复。 |
| `api-design.md` | 当前仓库没有 HTTP/RPC/GraphQL/WebSocket/插件 API 证据，也没有 API 变更请求。 |
| `database-design.md` | 当前只使用 `ConfigFile` 保存少量本地设置和聚合统计，没有数据库、迁移或跨版本 schema 设计需求；字段边界已并入 `technical-design.md`。 |
| `security-privacy.md` | 当前只存少量非敏感本地设置和聚合统计，无账号、联网、支付、凭据或遥测；边界并入 PRD 和技术设计即可。 |
| `release-plan.md` | 当前只有本地运行和未来导出准备，没有已确认的发布目标、feature flag、迁移或生产发布流程。 |
| `operations-runbook.md` | 仓库已有 `docs/runbook.md` 覆盖本地运行、测试和导出准备；没有长期运行服务或运维进程。 |
| `decision-log.md` | 关键取舍数量少，已合并到 `technical-design.md` 的关键决策。 |

## 后续开发入口

| 场景 | 先读 |
| --- | --- |
| 改用户可见玩法、UI 流程或 AI 难度 | `docs/planning/prd.md` |
| 改规则引擎、AI 决策或 UI 与规则层交互 | `docs/planning/technical-design.md` |
| 改测试、修规则 bug 或准备验收 | `docs/planning/test-plan.md` |
| 理解现有代码结构 | `docs/architecture.md` |
| 本地运行、测试或导出准备 | `docs/runbook.md` |
| 创建、替换或接入美术资源 | `docs/art-direction.md`、`assets/art/generated/README.md` |

## 待确认

| 问题 | 为什么不能从当前证据确定 |
| --- | --- |
| 目标发布平台和优先级 | `docs/runbook.md` 提到桌面、iOS 和 Steam 的未来准备项，但没有确认发布计划或顺序。 |
| 最终目标用户 | 仓库能证明这是本地单人原型，但没有说明面向练习玩家、休闲玩家、教学用途还是发布商品。 |
| 最终中文像素字体、动画范围和可访问性目标 | 当前已有视觉规范和 PNG 资产，但字体样张不可直接作为运行时字体；动画范围、输入策略和无障碍要求仍未确认。 |
| AI 强度目标 | 仓库能证明三档 AI 的实现方式，但没有可量化胜率、风格稳定性或性能预算目标。 |
| 更完整的存档范围 | 当前只保存 AI 数量、难度、音效/音乐开关和聚合战绩；是否保存当前牌局、筹码或历史明细仍待确认。 |
| 负责人、时间线和发布验收人 | 仓库没有项目管理或发布责任信息。 |

## 人工检查建议

- 请确认下一阶段是否仍保持“本地单人、无联网、无外部 API、无 LLM、无第三方插件”的边界；这会直接影响 PRD、技术设计和安全文档是否需要扩展。
- 请确认发布目标是否只是本地可玩，还是要优先准备桌面、Steam 或 iOS；当前 planning 没有生成 release plan，因为仓库证据不足。
- 请确认 AI 的“好玩”标准，例如更像真人、速度优先、难度可控或策略正确性优先；当前代码有实现机制，但没有产品指标。
- 请确认最终中文像素字体的选择与授权，以及哪些候选 atlas/VFX 需要继续切片和接入；当前仓库只能证明视觉方向和部分运行时集成。
