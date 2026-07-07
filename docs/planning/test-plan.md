# PokerGame 测试计划

## 文档目的

本文定义 PokerGame 当前原型的最小验证方式，帮助后续规则、AI 或 UI 改动在合并前证明没有破坏核心玩法。

本文仅根据当前仓库可见内容整理；没有证据的 CI、发布平台、性能门槛和设备矩阵均标记为 `待确认`。

## 适用范围

适用：

- Godot headless 脚本测试。
- 本地人工运行和牌局烟测。
- 规则引擎、AI 行动形状和 UI 主流程的回归验证。

不适用：

- 自动化 UI 点击测试、移动端设备测试、Steam 构建验证、联网压测或安全扫描。

## Plan 或项目证据

| 来源 | 已确认测试信息 |
| --- | --- |
| `README.md` | 测试命令为 `/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s tests/test_runner.gd`，期望输出 `All poker tests passed.` |
| `docs/runbook.md` | 本机 Godot Mono 依赖 `.NET 8`；主场景可用 `--quit-after 2` 做启动检查。 |
| `tests/test_runner.gd` | 当前测试覆盖牌组唯一性、牌型、kicker、非法 check、call、边池、分池、Hard AI 个性、AI 合法行动和 Monte Carlo 权益范围。 |
| `scripts/ui/main.gd` | 人工烟测需要覆盖菜单、三档难度、AI 数量、行动按钮、加注滑杆与步进按钮和结果面板。 |

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
2. 分别用 1、3、5 个 AI 开局。
3. 分别尝试 Simple、Medium、Hard 难度。
4. 在玩家回合尝试 fold、check、call、raise、all-in 中当前合法的行动。
5. 调整 raise 滑杆并确认加注按钮提交的金额合法。
6. 玩到无人争夺结算或摊牌，确认结果面板显示赢家、金额和牌型。
7. 点击 Next Hand 或 Restart，确认可继续游戏。
8. Hard 难度下确认 AI 座位显示 personality 标签。

## 回归场景建议

| 改动区域 | 应补充或重点执行 |
| --- | --- |
| `hand_evaluator.gd` | 增加具体牌型和 kicker 对照测试，尤其是 A-5 straight、同花、葫芦和边界平局。 |
| `poker_round.gd` | 增加下注轮、最小加注、all-in、多人边池、无人争夺和筹码重置测试。 |
| `ai_decision.gd` | 增加不同 stage、to_call、legal actions 下返回行动合法性的测试。 |
| `monte_carlo.gd` | 增加已知强牌/弱牌权益范围和 known-card 排除测试。 |
| `main.gd` | 做人工烟测，确认 UI 不直接破坏规则状态。 |

## 性能和稳定性

当前仓库没有性能预算。已知需要关注：

- Hard AI 的 Monte Carlo 次数会影响回合响应时间。
- 程序化 UI 每次重渲染会删除并重建节点，当前原型可接受；复杂 UI 或动画后需重新评估。
- 随机 AI 行为会让人工结果不可完全复现；如需要定位复杂 bug，可能要新增固定随机种子策略。

## 非目标

- 不在本文定义 CI 服务、GitHub Actions 或发布流水线。
- 不定义移动端、Steam 或桌面导出测试矩阵。
- 不要求现阶段增加自动化 UI 点击测试。
- 不测试外部 API、账号、支付或联网，因为当前项目没有这些边界。

## 实现指引

- 修 bug 时优先在 `tests/test_runner.gd` 复现，再修实现。
- 测试应围绕规则结果和公开方法，不依赖 UI 节点内部结构。
- 对随机行为，至少验证输出范围和行动合法性；不要把单次随机选择写成脆弱断言。
- 行为改变后同步更新 `README.md`、`docs/runbook.md` 或本目录相关文档。

## 验收标准

- 规则或 AI 改动：Godot headless 测试通过。
- UI 改动：主场景启动检查通过，并完成至少一轮人工烟测。
- 运行入口或资源引用改动：主场景启动检查通过，README/runbook 同步。
- 导出目标确认后：补充 release plan 和平台相关人工检查。

## 待确认

| 问题 | 影响 |
| --- | --- |
| 是否需要 CI 自动运行 Godot headless 测试 | 会影响测试命令的环境假设和仓库配置。 |
| 是否需要 UI 自动化测试 | 会影响场景拆分、测试工具和可观测状态设计。 |
| 是否需要性能预算 | 会影响 Monte Carlo 次数和目标设备验收。 |
| 是否需要平台测试矩阵 | 会影响桌面、Steam、iOS 或触控输入的验收范围。 |
| 是否需要固定随机种子 | 会影响 AI 和牌局 bug 的可复现性。 |
