# PokerGame 项目规划入口

项目为 Godot 4 + GDScript 单人德州扑克练习游戏。桌面可离线运行，规则、对手 AI、本地教练和规则文字复盘均在本地完成；联网时，回放会自动请求 Cloudflare 服务补充文字解读。

## 当前状态（2026-10-18 同步）

本次请求：每周同步活跃项目文档。工作模式：状态同步；规范项目目录为 `/Users/jerryszz/Desktop/Projects/pokerGame`。本次从独立副本核对远端默认分支、PR #34/#35 合并记录、项目配置及宣传片交付清单；没有重新运行游戏、渲染视频或验证公开渠道。10 月 12 日的版本与用户验收记录继续作为带日期的历史证据。

| 层次 | 已确认事实 | 证据与边界 |
| --- | --- | --- |
| 源码基线 | 本次同步起点 `origin/main` 为 `27a0b77`（已合入 PR #34/#35 宣传片工程与标题修订），项目版本 **1.4.0**。三手教程、练习、牌谱回放、统计与成就、对手风格、地狱难度、本地教练、离线文字复盘和六维画像均已实现。 | [项目配置](../../project.godot)、[架构](../architecture.md)、[教练与雷达定义](../architecture.md#coach-and-player-style)。此提交是文档同步起点，发行包来源另见发行记录。 |
| 公开版本（2026-10-12 核验） | **itch.io 提供 v1.4.0** 网页版及 Windows/macOS 下载；**GitHub 最新正式 Release 已同步为 v1.4.0**（2026-10-12）。 | [itch.io](https://jerryszz02.itch.io/poker-game)、[GitHub v1.4.0](https://github.com/Jerryszz02/pokerGame/releases/tag/v1.4.0)、[1.4.0 发布记录](../releases/1.4.0.md)。GitHub API 读回确认为 latest、非 draft、非 prerelease；tag 指向 `cb98f0b`，7 个附件的名称、大小和 SHA-256 与原包及 manifests 一致。 |
| 自动检查 | v1.4.0 发行记录保存了规则、AI、教程、保存、语言音频、布局、soak、工具及原生/Web 包检查结果。 | [Release PR CI](https://github.com/Jerryszz02/pokerGame/actions/runs/35846894269)、[1.4.0 验证记录](../releases/1.4.0.md#verification)。这是对应发行提交的历史检查；本次未在本地重跑游戏测试，文档 PR 的 CI 结果另见该 PR。 |
| 人工验收 | 用户于 2026-10-12 反馈已做完整实测，未发现明显问题。 | [用户验收记录](../releases/2026-10-12-owner-acceptance.md)。用户没有提供 OS、架构、浏览器或逐项日志；该反馈不扩写为所有平台矩阵逐项通过。 |
| Devlog（历史发布记录） | v1.4.0 帖子已列于 itch.io 公开页面，图文及媒体保存在仓库。 | [公开 Devlog](https://jerryszz02.itch.io/poker-game/devlog/1675112/pokergame-140-learn-by-playing-your-first-three-hands)、[Devlog 文本](../releases/1.4.0-devlog.md)、[发行记录](../releases/1.4.0.md)。本次同步未发布或编辑该帖子。 |

当前玩法包括：1～5 名 AI、四档难度、四档起始筹码和四组固定盲注、**三手真实牌桌教程（G1–G3）**、自由对战、基础练习（可逐手暂停）、最多 1000 手完整牌谱及回放、本地筛选统计与成就、中英文切换、Lounge 背景音乐、牌桌音效及独立音量。旧七课进度仅保留兼容处理，已不再是教程入口。

AI 已有 169 类翻前范围、当手公开行动推断、加权 Monte Carlo 胜率和有限行动收益评估。它是本地启发式模型，不是 CFR/GTO 求解器，也没有跨场次学习；测试通过不证明职业级强度。见 [AI 设计](../architecture.md#ai-layer)与[回归边界](test-plan.md#算法与教练回归)。

未完成对局续玩、联网对战和跨设备存档未纳入已确认范围。四条宣传片已于 2026-10-15 完成本地交付；[PR #34](https://github.com/Jerryszz02/pokerGame/pull/34) 的工程与 [PR #35](https://github.com/Jerryszz02/pokerGame/pull/35) 的横版大字/开场修订均已合入主干。当前采用 Store / Xiaohongshu 的 R3、Bilibili 的 R2、Shorts 的 R0，文件身份与独立审核见[宣传片交付入口](../promo-review/README.md)。成片交付和代码合并不代表视频已上传发布；主观试听仍未验证。原分镜继续见[宣传计划](../promo-video-scripts.md)。

已完成的一次性更新计划与实施过程已移出当前文档树，历史可通过 Git 查看。现行机制集中在[架构](../architecture.md)，操作与维护在[玩家指南](../player-guide.md)和 [Runbook](../runbook.md)，验证入口保留在下列长期项目文档中。

本次仅同步本索引中的源码基线和宣传片完成状态，无新增或退役 planning 文件。最小检查为 `python3 /Users/jerryszz/.agents/skills/plan-project-docs/scripts/audit_planning_docs.py --root <项目根目录>`，仅核对索引和本地链接。未重复游戏全量验收；自动验证和人工反馈各自沿用带日期的证据。

待确认：用户实测的具体 OS、架构、浏览器与逐项结果没有记录。GitHub Release 同步的读回核对属于 2026-10-12 历史记录，本轮未重复渠道验收；本次文档 PR 的检查须按该 PR 实际运行记录确认。

## 文档索引

| 文档 | 职责 |
| --- | --- |
| [../promo-review/README.md](../promo-review/README.md) | 四条宣传片交付、最终轮次、审核与未发布/试听边界。 |
| [../architecture.md](../architecture.md) | 当前规则、AI、持久化、教练和六维画像机制。 |
| [../runbook.md](../runbook.md) | 本地检查、语言音频、Cloudflare 运维、构建与网络边界。 |
| [../releases/1.4.0.md](../releases/1.4.0.md) | 当前版本的构建来源、公开渠道、Devlog 和验证限制。 |
| [../releases/2026-10-12-owner-acceptance.md](../releases/2026-10-12-owner-acceptance.md) | 本次用户完整实测反馈及证据边界。 |
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
