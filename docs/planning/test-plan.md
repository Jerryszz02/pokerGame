# PokerGame 测试计划

> 范围说明：下文保留原型/首发回归基线，练习产品和教练的现行检查入口见文末补充。测试要求与脚本存在不表示本次已运行；实际通过情况以对应提交的日志、CI 和发行记录为准。

## 文档目的

本文定义 PokerGame 当前原型的最小验证方式，帮助后续规则、AI 或 UI 改动在合并前证明没有破坏核心玩法。

本文件保留原型回归入口。2026-09-06 起进入稳定公开桌面首发，新增 CI、性能、长局、发行包和目标设备验收以 [release-plan.md](release-plan.md) R1–R9 为准；目标要求不是已通过记录。

算法升级的范围、信息边界和收益数学验收见[算法与教练回归](#算法与教练回归)。运行命令统一维护在 [runbook.md](../runbook.md)，不将风格差异或规则测试通过当作实战强度证明。

## 适用范围

适用：

- Godot headless 脚本测试。
- 本地人工运行和牌局烟测。
- 规则引擎、中文结果/事件、本地 profile、AI 行动形状和 UI 主流程的回归验证。
- 菜单、设置弹窗、桌面布局、关键生成式美术接入探针和窗口模式完整点击流。

不适用：

- 移动端设备测试、Steam 构建验证、联网压测或安全扫描。

## Plan 或项目证据

| 来源 | 已确认测试信息 |
| --- | --- |
| `README.md` | 测试命令为 `/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s tests/test_runner.gd`，期望输出 `All poker tests passed.` |
| `docs/runbook.md` | 本机 Godot Mono 依赖 `.NET 8`；主场景可用 `--quit-after 2` 做启动检查。 |
| `tests/test_runner.gd` | 当前测试覆盖规则、中文牌型/结果、事件、local profile、AI 个性/抽样/合法行动和 Monte Carlo 权益范围。 |
| `tests/ui_layout_probe.gd` | 覆盖 1280x720 菜单/设置，以及 1280x720、1440x900、1920x1080 桌面布局和关键纹理接入。 |
| `tests/ui_playthrough_probe.gd` | 窗口模式覆盖设置重置、日志、暂停/继续、加注展开、全下、结算、下一手、重开和 AI 回合中返回菜单。 |
| `scripts/ui/main.gd` | 人工烟测需要覆盖菜单、设置/统计、三档难度、AI 数量、事件日志、行动控件、盲注、生成美术和结果面板。 |

## 自动化检查

### Godot headless 测试

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s tests/test_runner.gd
```

通过标准：

- 命令退出码为 0。
- 输出包含 `All poker tests passed.`。

当前覆盖：

| 场景 | 覆盖点 |
| --- | --- |
| 牌组 | 洗牌后可抽出 52 张唯一牌。 |
| 手牌评估 | 覆盖 high card 到 straight flush。 |
| kicker | 同牌型时能用 kicker 比较。 |
| 行动校验 | 面对 big blind 时不能 check，call 可成功。 |
| 边池 | 短筹码 all-in 玩家只能赢符合投入额的主池，次优玩家可赢边池。 |
| 分池 | 公共牌形成相同最大牌时双方平分底池。 |
| AI | Hard AI 分配个性，AI 返回合法行动。 |
| Monte Carlo | 权益结果保持在 0..1。 |
| 中文与事件 | 结果牌型为中文，事件覆盖开局、盲注、行动、自动发牌和结算。 |
| 本地 profile | 设置和统计可 round-trip，非法值被规范化，统计可重置。 |
| AI 采样 | 不同难度/人格的行动输出保持合法且具备预期形状。 |

### UI 布局与资源探针

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s tests/ui_layout_probe.gd
```

通过标准：

- 命令退出码为 0。
- 输出包含 `All UI layout probes passed.`。
- 菜单、设置和桌面控件不越界。
- 全屏牌桌、浮动控件、角色安全区、模块化筹码、运行时 `StyleBoxFlat` 状态、nearest-neighbor 纹理和统计重置确认符合当前约束。

### UI 完整点击流

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --path . -s tests/ui_playthrough_probe.gd
```

通过标准：

- 命令退出码为 0。
- 菜单、日志抽屉、暂停/继续、加注展开、全下、结算、下一手和返回菜单路径均完成。
- 日志或暂停状态阻止 AI 推进；AI 回合中返回菜单后，排队回调不会恢复旧牌桌。
- 各状态截图写入 `/tmp/poker_audit/`，并满足 `docs/planning/ui-acceptance.md` 的 M1-M8。

### 主场景启动检查

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --path . --quit-after 2
```

通过标准：

- Godot 能加载项目和主场景。
- 没有因为缺失场景、脚本或资源引用导致启动失败。

## 人工烟测

每次修改 UI、规则流程或 AI 决策后，至少执行：

1. 从 Godot Project Manager 导入 `/Users/jerryszz/Desktop/Projects/pokerGame/project.godot`，运行 `res://scenes/main.tscn`。
2. 确认生成式菜单背景、标题、桌面预览、选择控件和按钮清晰显示；打开设置检查开关、统计和两步重置。
3. 分别用 1、3、5 个 AI 开局，并尝试简单、中等、困难三档难度。
4. 打开日志抽屉，确认它覆盖牌桌且 AI 暂停；关闭后确认牌局恢复。
5. 从牌局设置暂停并继续；再次暂停后返回菜单，确认排队中的 AI 行动不会恢复旧牌桌。
6. 在玩家回合尝试 fold、check、call、raise、all-in 中当前合法的行动。
7. 调整 raise 滑杆并确认加注按钮提交的金额合法。
8. 玩到无人争夺结算或摊牌，确认结果面板显示赢家、金额和牌型。
9. 确认事件日志只显示真实事件，大小盲标识不会被后续行动覆盖。
10. 点击“下一手”或“重新开始”，确认可继续游戏且聚合统计每手只更新一次。
11. 困难难度下确认 AI 座位显示人格标签，所有难度的 AI 行动都有可感知的随机间隔。

## 回归场景建议

| 改动区域 | 应补充或重点执行 |
| --- | --- |
| `hand_evaluator.gd` | 增加具体牌型和 kicker 对照测试，尤其是 A-5 straight、同花、葫芦和边界平局。 |
| `poker_round.gd` | 增加下注轮、最小加注、all-in、多人边池、无人争夺和筹码重置测试。 |
| `ai_decision.gd` | 增加不同 stage、to_call、legal actions 下返回行动合法性的测试。 |
| `monte_carlo.gd` | 增加已知强牌/弱牌权益范围和 known-card 排除测试。 |
| `local_profile.gd` | 增加缺失/非法配置回退、round-trip、重置和未来字段兼容测试。 |
| `main.gd` 或生成美术 | 运行 UI 布局探针与启动检查，再做人工烟测确认纹理、动态文字和规则边界。 |

## 性能和稳定性

原型阶段未设性能预算；首发新增预算见 release plan R3，尚待实现和验证。已知需要关注：

- Hard AI 的 Monte Carlo 次数会影响回合响应时间。
- 程序化 UI 每次重渲染会删除并重建节点，当前原型可接受；复杂 UI 或动画后需重新评估。
- 随机 AI 行为会让人工结果不可完全复现；如需要定位复杂 bug，可能要新增固定随机种子策略。
- 当前 UI 布局探针通过后仍可能报告 `1 ObjectDB instance was leaked at exit`；退出码 0 且成功文本存在时不视为布局失败，但数量增长或非零退出码需要重新排查节点清理。

## 非目标

- CI 与发布流水线由 release plan 和后续构建配置定义。
- 移动端与 Steam 不属于默认首发范围；桌面导出矩阵按 release plan 执行。
- 不要求移动端或平台级输入自动化；当前完整点击流只覆盖本地桌面窗口模式。
- 不测试外部 API、账号、支付或联网，因为当前项目没有这些边界。

## 实现指引

- 修 bug 时优先在 `tests/test_runner.gd` 复现，再修实现。
- 测试应围绕规则结果和公开方法，不依赖 UI 节点内部结构。
- 对随机行为，至少验证输出范围和行动合法性；不要把单次随机选择写成脆弱断言。
- 行为改变后同步更新 `README.md`、`docs/runbook.md` 或本目录相关文档。

## 验收标准

- 规则或 AI 改动：Godot headless 测试通过。
- UI 改动：UI 布局探针、完整点击流与主场景启动检查通过，并审查 `/tmp/poker_audit/` 截图。
- 运行入口或资源引用改动：UI 布局探针与主场景启动检查通过，README/runbook/美术规范同步。
- 导出目标确认后：补充 release plan 和平台相关人工检查。

## 待确认

| 问题 | 影响 |
| --- | --- |
| 是否需要 CI 自动运行 Godot headless 测试 | 会影响测试命令的环境假设和仓库配置。 |
| 是否需要性能预算 | 会影响 Monte Carlo 次数和目标设备验收。 |
| 是否需要平台测试矩阵 | 会影响桌面、Steam、iOS 或触控输入的验收范围。 |
| 是否需要固定随机种子 | 会影响 AI 和牌局 bug 的可复现性。 |

## 首发可执行检查（2026-09-07）

推荐入口：`python3 tools/verify.py --godot <Godot路径>`；加 `--windowed` 运行三种分辨率的完整窗口流程。包装器同时检查退出码、成功标记和脚本错误，避免 Godot 某些脚本错误退出码为 0 时误报成功。

- `test_runner.gd`：增加 1,504 组独立牌型参考、短盲注、加注权、无对手可下注的边池边界、分池余数、退款、淘汰轮转和 profile 类型恢复。
- `rules_soak.gd`：固定种子 20260906，10,000 手，逐行动验证资金、牌、合法性和步数上限。
- `ai_runtime_probe.gd`：真实后台 worker 的暂停/日志/恢复/旧结果丢弃/快速重开/排队玩家输入回归。
- `ui_lifecycle_probe.gd`：40 次牌桌重绘后回菜单，不能残留循环材质动画。
- `ui_stability_probe.gd`：窗口模式真实调度，默认 1,800 秒，至少 100 次 AI 行动，记录帧延迟、节点、对象、动画和内存。短参数运行只用于调试，不作为 30 分钟通过证据。
- 构建包 `--headless -- --self-test`：从独立目录验证模板、场景/字体、9 组人数/难度及统计幂等。该检查不替代 R7 目标系统图形测试。真人试玩已按用户要求移出首发 Goal，见 release plan 的 R8。

Windows/macOS 构建和自检进入 `.github/workflows/desktop.yml`；CI 是否通过必须查对应提交的实际运行。新的验收结果放在发行报告，不在这里预填成功状态。

## 练习产品回归（2026-09-10）

`tests/practice_data_test.gd`、`tests/practice_save_retry_test.gd`、`tests/tutorial_test.gd`、`tests/practice_ui_probe.gd` 已接入 `tools/verify.py`；`--windowed` 同时执行新旧点击流。覆盖 80 组人数/筹码/盲注配置、教程正误与重练、合法动作、真实回放视角、损坏/未知版本保护、保存失败重试、容量限制、幂等统计、筛选和删除牌谱后保留累计。数据口径见[架构](../architecture.md#local-persistence-and-audio)，操作指标见 [UI 验收](ui-acceptance.md#练习产品页面2026-09-10)。

## 中英文与音频回归

`tests/localization_test.gd`、`tests/localization_ui_probe.gd`、`tests/audio_test.gd` 和 `tests/profile_save_debounce_test.gd` 已接入 `tools/verify.py`，覆盖翻译模板参数、语言切换/持久化、旧记录展示、音频资源与独立音量及保存防抖。导出后的资源检查与浏览器实际播放仍单独验证，命令和听感边界见 [Runbook](../runbook.md#中英文与音频)。

## 算法与教练回归

Godot 回归与本机服务测试已接入 `tools/verify.py`；Worker 使用独立的 `Coach Worker checks` CI。测试使用隔离数据和固定种子/提供方响应，验证实现边界；线上服务、听感和跨平台体验仍独立验收。

| 检查入口 | 必须保留的覆盖 |
| --- | --- |
| `tests/test_ai_strategy.gd`、`tests/test_ai_observations.gd` | 169 类翻前范围、位置/价格/筹码尺度、阻断及联合抽样、解析边池收益、成功行动历史、快照深拷贝和隐藏信息不变性。 |
| `tests/coach_core_test.gd` | 决策前上下文及 JSON 往返、再加注权、旧/缺字段记录降级、独立 RNG、共享样本与实际下注尺寸、采样误差/取消及地狱行动合法性。 |
| `tests/coach_product_test.gd`、`tests/all_in_luck_test.gd` | 六维分母和门槛、强制盲注/全下跟注分类、统计筛选、幂等持久化、回放删除后累计保留、全下锁定资格、边池及退款。 |
| `tests/coach_ui_probe.gd` | 实时提示与辅助记账、回放自动分析、旧回调失效、全知视角隔离、空样本与中英文窗口布局；`--windowed` 加跑可见窗口。 |
| `tests/deepseek_review_test.gd`、`tests/local_replay_review_test.gd`、`tools/test_coach_service.py` | 有界数值摘要、决定引用/输出校验、本地规则文字、失败冷却与云端回退、Godot 到本机服务的 HTTP 契约；不以固定响应证明真实模型质量。 |
| `services/coach-worker/test/` | Worker/SQLite Durable Object 的并发准入、重启持久额度、请求合并、缓存、失败计数、输入/输出限制、超时和来源校验；执行命令见 [Runbook](../runbook.md#cloudflare-文字复盘服务)。 |

地狱、实时提示和回放的耗时用 `tests/coach_benchmark.gd` 记录具体机器、版本和样本；固定牌序、座位轮换的对战样本不自动证明强度提升。六维口径与信息边界见[架构](../architecture.md#coach-and-player-style)，浏览器和目标设备尚未完成的验收见[发布记录](../releases/1.3.0.md#verification-and-limits)。
