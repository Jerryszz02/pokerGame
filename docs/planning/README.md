# PokerGame 项目规划入口

当前请求：补全起手范围、对手范围估计和行动收益评估。工作模式：算法实施与验收；保留已归档的非算法产品规划。更新日期：2026-09-10。项目根目录：`/Users/jerryszz/Desktop/Projects/pokerGame`。

## 当前规划与代码状态

项目是 Godot 4 + GDScript 中文离线单人德州扑克。后续定位为免费德扑练习游戏；首页三模式、可配置牌桌、分步教学、回放、细化统计和成就处于 `计划中`，不因文档提交而视为已经实现。

非算法产品规划由 `agent/practice-product-plan` 归档。当前 `agent/ai-range-ev` 补全了起手范围、公开行动推断和有限行动收益评估，设计与验收边界见 [ai-strategy-plan.md](ai-strategy-plan.md)。现有界面仍以人数/难度开桌、固定初始筹码与盲注、静态说明及本地聚合统计为基线。具体实现以代码和 [架构说明](../architecture.md) 为准。

本轮算法已通过 `tools/verify.py --windowed`：新增策略/信息边界测试、规则万手 soak、后台生命周期、布局和三种分辨率窗口流程；macOS 构建及包自检通过。实战强度和专业训练效果尚未验证，也没有重新验证公开 Release 或 itch.io。下面的首发材料是历史范围及证据入口，不能把其中旧的“候选验收中”当作今天的发布状态。

## 文档索引与分工

| 文档 | 用途与本次处理 |
| --- | --- |
| [ai-strategy-plan.md](ai-strategy-plan.md) | **新增：算法实现与验收入口**。定义起手范围、公开行动推断、行动收益模型及性能与训练边界；不包含产品模式 UI 或 CFR。 |
| [practice-product-plan.md](practice-product-plan.md) | 已归档的非 AI 算法需求入口。集中维护已确定需求、建议方案、数据边界、实施阶段、验收和待确认事项。 |
| [prd.md](prd.md) | 原型/首发产品基线。更新范围声明及被新规划替代的成就、逐手历史非目标；规则约束保留。 |
| [technical-design.md](technical-design.md) | 原型/首发技术基线。补充新规划关系，区分完结牌谱与进行中对局续玩；算法实现以 ai-strategy-plan 为准。 |
| [test-plan.md](test-plan.md) | 既有规则、AI、配置与首发回归策略；注明新功能尚需追加对应测试，旧测试不证明新能力。 |
| [ui-acceptance.md](ui-acceptance.md) | 既有布局、清晰度、暂停与点击流指标；注明新流程的增补要求和旧 UI 修复任务的范围。 |
| [release-plan.md](release-plan.md) | 2026-09-07 稳定桌面首发的历史范围与 R1–R9 验收基线；补充历史定位及新规划链接。 |

新增规划覆盖旧文档中与本轮目标冲突的产品非目标，不覆盖行动合法性、牌型评估、规则/AI/UI 分层和离线约束。没有文档被退役。

根 [README](../../README.md) 面向玩家下载与快速开始；[架构](../architecture.md) 和 [Runbook](../runbook.md) 描述实际代码与运行方法；本目录描述设计目标。实现变化时在对应 PR 同步受影响的现状文档，不能提前把规划能力写进玩家介绍。

## 本次证据与检查

- 需求依据：2026-09-10 用户对免费练习定位、三模式、开桌设置、教程、速览、回放、统计和成就的说明，以及“完全本地分析教练”的选择。
- 代码依据：`scripts/ui/main.gd`、`scripts/game/poker_round.gd`、`scripts/game/table_state.gd`、`scripts/game/local_profile.gd`；`scripts/ai/`、相关策略/观察测试及 AI worker 快照构成本轮算法实现证据。
- 文档依据：本目录既有六篇规划、[架构](../architecture.md)、[Runbook](../runbook.md) 及既有玩家说明。
- 本轮检查：完整窗口回归、万手规则 soak、AI 决策基准、macOS 包自检、planning 文档审计及 `git diff --check`。规则与合法性检查不证明竞技强度；本地构建不代表公开发布。
- 后续实施使用的引擎与命令沿用 [Runbook](../runbook.md)。新功能验收见 [规划验收清单](practice-product-plan.md#12-验收清单)。

## 文档选择与待确认

产品规划与算法设计分别维护在两篇独立文档，本索引和既有基线同步其范围。用户流程、数据保存、成就口径和阶段验收集中在新规划，暂不拆成重复的 PRD、数据库、用户流程或决策日志。没有新增外部 API、在线服务或运维职责，因此不创建 API/在线运维文档。算法实现同步现状架构和 Runbook；本轮不修改模式与教学 UI。

待确认：大小盲预设、是否逐座位选性格、教程课数与文案、牌谱保留/删除语义、成就门槛及辅助模式计入方式。本轮算法的难度预算与性格参数见 ai-strategy-plan；教练分析与画像计算仍待后续设计。完整清单见 [新规划](practice-product-plan.md#13-待确认与维护契约)。

## 历史首发证据

2026-09-07 首发工作定义了 R1–R9，并取消 R8 真人试玩门；该取消只描述当次首发范围，不代表体验已获验证。

- [2026-09-07 桌面验收记录](../releases/2026-09-07-desktop-acceptance.md)：当次逐门结果和未通过项，不证明今天的发布状态。
- [可选试玩记录模板](../releases/playtest-template.md)：用于后续自愿收集产品体验反馈。
- [玩家说明](../player-guide.md)、[美术规范](../art-direction.md)：已有操作与视觉参考；具体实现阶段再核对和更新相关内容。

当前发布事实需重新核对 GitHub Release/CI、对应提交和公开下载；运行状态需重新核对实际包与目标设备。不要把 Git 合并、文档计划或旧验收日志互相替代。
