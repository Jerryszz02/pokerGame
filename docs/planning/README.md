# PokerGame 项目规划入口

项目为 Godot 4 + GDScript 单人德州扑克练习游戏。桌面可离线运行，1.2.0 源码另有 Web 候选构建；游戏逻辑与 AI 均在本地运行。

## 当前状态（2026-09-11 核对）

| 层次 | 已确认事实 | 证据与边界 |
| --- | --- | --- |
| 公开版本 | GitHub 最新正式版本为 **v1.1.0**，提供 Windows x64 / macOS Universal ZIP；itch.io 页面仍为简体中文桌面下载入口。 | [GitHub Release](https://github.com/Jerryszz02/pokerGame/releases/tag/v1.1.0)、[itch.io 页面](https://jerryszz02.itch.io/poker-game)。本次核对页面及附件元数据，未重新下载运行。 |
| 最新主线 | `0466f28`，项目版本 **1.2.0**。AI 增强、练习功能、双语音频、Web 构建和版本准备均已合入。 | [PR #12](https://github.com/Jerryszz02/pokerGame/pull/12)～[PR #17](https://github.com/Jerryszz02/pokerGame/pull/17) 已合并；1.2.0 尚非公开 Release。 |
| 自动验证 | 该主线提交的规则/headless 检查、Windows 包、macOS 包和 Web 包四项 CI 作业均成功。 | [CI 运行 34560282938](https://github.com/Jerryszz02/pokerGame/actions/runs/34560282938)。桌面包自检与 Web ZIP 检查不替代实际图形界面、浏览器及 itch 内嵌验收。 |
| Web 体验 | 已记录用户本地预览未报告问题；完整浏览器存储/音频矩阵和 itch 内嵌验证仍待完成。 | [Web 发布流程](../itchio-release.md)、[1.2.0 发布说明](../releases/1.2.0.md)。 |

当前玩法包括：1～5 名 AI、三档难度、四档起始筹码和四组固定盲注、七课互动教程、自由对战、基础练习（可逐手暂停）、最多 1000 手完整牌谱及回放、本地筛选统计与成就。1.2.0 源码新增中英文切换、Lounge 背景音乐、牌桌音效及独立音量。

AI 已有 169 类翻前范围、根据当手公开行动估计对手范围、加权 Monte Carlo 胜率和有限行动收益评估。它是本地启发式模型，不是 CFR/GTO 求解器，也没有跨场次学习；测试通过不证明职业级强度。见 [AI 设计与验证边界](ai-strategy-plan.md)。

仍未提供本地教练建议、画像雷达评分、未完成对局续玩、联网对战或跨设备存档。下一步发布工作应按 Web 验收表核对实际包、音频解锁、刷新后的存档和 itch 内嵌，再发布 1.2.0 并同步公开页面。

练习功能的原实现分支和测试过程保留在[实施记录](practice-implementation.md)，属于历史证据。后续状态以对应提交、实际检查和公开发布核对为准。

## 文档索引

| 文档 | 职责 |
| --- | --- |
| [bilingual-audio-plan.md](bilingual-audio-plan.md) | 中英文切换、音频资源与该轮验收记录。 |
| [../itchio-release.md](../itchio-release.md) | Web 构建、浏览器存储与 itch.io 发布验收表。 |
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
