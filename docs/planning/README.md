# PokerGame 项目规划入口

项目为 Godot 4 + GDScript 中文离线单人德州扑克，当前按免费练习游戏定位实施产品升级。用户于 2026-09-10 确认执行 P1～P5 非算法功能；起手范围、公开行动推断和有限行动收益评估已实现；教练和画像评分仍待独立讨论。

## 当前工作

实现分支 `agent/practice-product-implementation` 从已更新的 `origin/main`（`7d27d18`）建立，并带入原规划提交。具体实施选择、验收命令与结果统一维护在 [实施记录](practice-implementation.md)。未通过验收的项目不得标记完成；本地测试、PR、公开发布分别陈述。

算法设计与验证边界见 [ai-strategy-plan.md](ai-strategy-plan.md)。规则与合法性检查不证明实战强度，Git 合并不代表公开发布。

## 文档索引

| 文档 | 职责 |
| --- | --- |
| [ai-strategy-plan.md](ai-strategy-plan.md) | 起手范围、公开行动推断、行动收益模型及性能与训练边界。 |
| [practice-product-plan.md](practice-product-plan.md) | P1～P5 产品要求、非目标、数据口径、N1～N10 验收与后续算法依赖。 |
| [practice-implementation.md](practice-implementation.md) | 已确认的默认方案、本轮实现边界及实际验收证据。 |
| [prd.md](prd.md) | 原型/首发基线；逐手历史、成就等旧非目标被练习产品规划替代。 |
| [technical-design.md](technical-design.md) | 原型技术约束；规则/AI/UI 分层仍生效。 |
| [test-plan.md](test-plan.md) | 既有回归与新功能验证入口。 |
| [ui-acceptance.md](ui-acceptance.md) | 最小窗口、控件/文字、暂停与实际点击流标准。 |
| [release-plan.md](release-plan.md) | 历史桌面首发验收门；不作为当前公开发布已完成的证明。 |

根 [README](../../README.md) 面向玩家快速开始；[架构](../architecture.md) 与 [Runbook](../runbook.md) 说明实际实现、存档和检查命令。规划说明目标，实施记录说明本次证据，不用旧文档状态代替当前代码或发布核验。

## 历史首发证据

2026-09-07 首发工作定义了 R1–R9，并取消 R8 真人试玩门；该取消只描述当次首发范围，不代表体验已获验证。

- [2026-09-07 桌面验收记录](../releases/2026-09-07-desktop-acceptance.md)：当次逐门结果和未通过项，不证明今天的发布状态。
- [可选试玩记录模板](../releases/playtest-template.md)：用于后续自愿收集产品体验反馈。
- [玩家说明](../player-guide.md)、[美术规范](../art-direction.md)：已有操作与视觉参考；具体实现阶段再核对和更新相关内容。

当前发布事实需重新核对 GitHub Release/CI、对应提交和公开下载；运行状态需重新核对实际包与目标设备。不要把 Git 合并、文档计划或旧验收日志互相替代。
