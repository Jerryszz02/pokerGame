# PokerGame 项目规划入口

项目为 Godot 4 + GDScript 单人德州扑克练习游戏。桌面可离线运行，规则、对手 AI、本地教练和规则文字复盘均在本地完成；联网时，回放会自动请求 Cloudflare 服务补充文字解读。

## 当前状态（2026-09-18 核对）

| 层次 | 已确认事实 | 证据与边界 |
| --- | --- | --- |
| 源码基线 | 本次核对的 `origin/main` 为 `ca5e1b0`，项目版本 **1.3.0**。对手风格、地狱难度、本地教练、回放分析、离线文字复盘和六维画像均已实现。 | [项目配置](../../project.godot)、[架构](../architecture.md)、[教练与雷达定义](../architecture.md#coach-and-player-style)。 |
| 公开版本 | **itch.io 提供 v1.3.0** 网页版及 Windows/macOS 下载；**GitHub Releases 最新为 v1.2.0**。 | 本次直接核对 [itch.io 公开页面](https://jerryszz02.itch.io/poker-game)的两个 Version 1.3.0 下载条目及 [GitHub Release](https://github.com/Jerryszz02/pokerGame/releases/tag/v1.2.0)。包来源、Butler 渠道及上传验证见 [1.3.0 发布记录](../releases/1.3.0.md)。 |
| 自动检查 | `ca5e1b0` 的规则、Windows 包、macOS 包、Web 包与 Worker 检查均成功。 | [构建 CI](https://github.com/Jerryszz02/pokerGame/actions/runs/35358793748)、[Worker CI](https://github.com/Jerryszz02/pokerGame/actions/runs/35358793627)。此轮 CI 的上传作业跳过；检查结果本身不证明上传或完整运行验收。 |
| Devlog | v1.3.0 帖子已公开，页面元数据记录 2026-09-18 15:06 UTC 发布。 | 本次无登录读取[公开文章](https://jerryszz02.itch.io/poker-game/devlog/1668455/pokergame-130-know-your-play-choose-your-challenge)；原始草稿交付与图片来源保留在[素材记录](../media/v1.3.0/README.md)。 |
| 运行验证 | 本次整理核对源码、CI 和公开页面，未重跑游戏。完整浏览器启动、音频/存储、Windows GUI 与 Intel Mac 验收仍未完成。 | [发布验证及限制](../releases/1.3.0.md#verification-and-limits)、[云端服务联调记录](../runbook.md#cloudflare-文字复盘服务)。服务健康检查、公开入口和候选包检查各有独立边界。 |

当前玩法包括：1～5 名 AI、四档难度、四档起始筹码和四组固定盲注、七课互动教程、自由对战、基础练习（可逐手暂停）、最多 1000 手完整牌谱及回放、本地筛选统计与成就。1.2.0 源码新增中英文切换、Lounge 背景音乐、牌桌音效及独立音量。

AI 已有 169 类翻前范围、根据当手公开行动估计对手范围、加权 Monte Carlo 胜率和有限行动收益评估。它是本地启发式模型，不是 CFR/GTO 求解器，也没有跨场次学习；测试通过不证明职业级强度。见 [AI 设计](../architecture.md#ai-layer)与[回归边界](test-plan.md#算法与教练回归)。

v1.3.0 已提供本地教练建议和六维画像。仍未提供未完成对局续玩、联网对战或跨设备存档。后续可补充浏览器兼容性与持久化的复验证据，并同步 GitHub Release；这些验证事项不表示音频、存档或 itch 内嵌功能尚未实现。

已完成的一次性更新计划与实施过程已移出当前文档树，历史可通过 Git 查看。现行机制集中在[架构](../architecture.md)，操作与维护在[玩家指南](../player-guide.md)和 [Runbook](../runbook.md)，验证入口保留在下列长期项目文档中。

## 文档索引

| 文档 | 职责 |
| --- | --- |
| [../architecture.md](../architecture.md) | 当前规则、AI、持久化、教练和六维画像机制。 |
| [../runbook.md](../runbook.md) | 本地检查、语言音频、Cloudflare 运维、构建与网络边界。 |
| [../releases/1.3.0.md](../releases/1.3.0.md) | 当前版本的构建来源、公开渠道、Devlog 和验证限制。 |
| [../itchio-release.md](../itchio-release.md) | Web 构建、浏览器存储与 itch.io 发布验收表。 |
| [prd.md](prd.md) | 原型/首发需求基线，保留原始产品约束与决策背景。 |
| [technical-design.md](technical-design.md) | 原型技术约束；规则/AI/UI 分层仍生效。 |
| [test-plan.md](test-plan.md) | 核心、练习、语言、教练及云端服务的回归入口。 |
| [ui-acceptance.md](ui-acceptance.md) | 最小窗口、控件/文字、暂停与实际点击流标准。 |
| [release-plan.md](release-plan.md) | 初始桌面发布的验收门与原始范围。 |

根 [README](../../README.md) 面向玩家快速开始；[架构](../architecture.md) 与 [Runbook](../runbook.md) 说明实际实现、存档和检查命令。规划说明目标，发行记录说明对应版本的证据，不用旧文档状态代替当前代码或发布核验。

## 历史发布核对（2026-09-11）

| 层次 | 已确认事实 | 证据与边界 |
| --- | --- | --- |
| 公开版本 | **itch.io 已公开 v1.2.0**，页面提供 Run game、Windows x64 / macOS Universal ZIP 和校验文件；**GitHub latest 仍为 v1.1.0**。 | [GitHub Release](https://github.com/Jerryszz02/pokerGame/releases/tag/v1.1.0)、[itch.io 页面](https://jerryszz02.itch.io/poker-game)。本次核对页面及附件元数据，未重新下载运行。 |
| 已验证实现基线 | `0466f28`（1.2.0 实现基线，不代表后续最新主线），项目版本 **1.2.0**。AI 增强、练习功能、双语音频、Web 构建和版本准备均已合入。 | [PR #12](https://github.com/Jerryszz02/pokerGame/pull/12)～[PR #17](https://github.com/Jerryszz02/pokerGame/pull/17) 已合并；1.2.0 已在 itch.io 发布，但尚无对应 GitHub Release。 |
| 自动验证 | 该实现基线提交的规则/headless 检查、Windows 包、macOS 包和 Web 包四项 CI 作业均成功。 | [CI 运行 34560282938](https://github.com/Jerryszz02/pokerGame/actions/runs/34560282938)。桌面包自检与 Web ZIP 检查不替代实际图形界面、浏览器及 itch 内嵌验收。 |
| Web 体验 | 已记录用户本地预览未报告问题；浏览器音频和本地存档已实现，公开 itch.io 页面已提供内嵌启动入口。本次未重新执行完整音频/持久化与浏览器兼容矩阵。 | [Web 发布流程](../itchio-release.md)、[1.2.0 发布说明](../releases/1.2.0.md)。 |

## 历史首发证据

2026-09-07 首发工作定义了 R1–R9，并取消 R8 真人试玩门；该取消只描述当次首发范围，不代表体验已获验证。

- [2026-09-07 桌面验收记录](../releases/2026-09-07-desktop-acceptance.md)：当次逐门结果和未通过项，不证明今天的发布状态。
- [可选试玩记录模板](../releases/playtest-template.md)：用于后续自愿收集产品体验反馈。
- [玩家说明](../player-guide.md)、[美术规范](../art-direction.md)：已有操作与视觉参考；具体实现阶段再核对和更新相关内容。

当前发布事实需重新核对 GitHub Release/CI、对应提交和公开下载；运行状态需重新核对实际包与目标设备。不要把 Git 合并、文档计划或旧验收日志互相替代。
