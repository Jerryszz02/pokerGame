# PokerGame 项目规划入口

请求：稳定公开桌面首发，先定义验收再实施。工作模式：实施与验收。更新日期：2026-09-07。项目根目录：`/Users/jerryszz/Desktop/Projects/pokerGame`；本轮 worktree：`/Users/jerryszz/Desktop/Projects/pokerGame-release`。

项目是 Godot 4 + GDScript 中文离线单人德州扑克。首发目标、验收门和执行顺序以 [release-plan.md](release-plan.md) 为准。当前处于候选构建验收阶段，尚未满足公开发布门。

## 设计与验收文档

- [release-plan.md](release-plan.md)：新增，R1–R9 定义稳定公开桌面首发，含真实发行包、目标平台与真人试玩门。
- [prd.md](prd.md)：已有产品需求和离线边界；首发新增要求见 release plan，旧原型描述不覆盖首发目标。
- [technical-design.md](technical-design.md)：已有架构与实现约束，随对应阶段更新。
- [test-plan.md](test-plan.md)：原型回归入口；发布性能、CI、设备矩阵现已纳入首发范围，见 release plan。
- [ui-acceptance.md](ui-acceptance.md)：M1–M8 布局与截图指标，首发增加帮助、退出确认和比赛总结状态。

## 当前证据与维护文档

本轮核对 `AGENTS.md`、`project.godot`、规则/AI/UI/测试脚本及 `origin/main`（起点 `ebf7623`）。前序同日审计规则、布局和完整窗口流程均通过，但额外复现短盲注停滞、全下绕过加注权和多人出局结算缺口。此记录是基线历史，不证明后续分支或发行包通过。

- [README](../../README.md)：面向首次访问者的介绍与运行入口；发布阶段改为玩家下载入口。
- [架构说明](../architecture.md)：当前实现，随代码同 PR 更新。
- [运行手册](../runbook.md)：开发验证、构建和本地数据，随对应机制更新。
- [美术规范](../art-direction.md)：美术方向和动态文本边界。

规则入口：`Godot --headless --path . -s tests/test_runner.gd`；布局：`Godot --headless --path . -s tests/ui_layout_probe.gd`；窗口流程：`Godot --path . -s tests/ui_playthrough_probe.gd`。发布验证已固定 Godot 4.7.2 标准版及匹配模板，由 `tools/bootstrap_godot.py` 获取并校验。本机旧 Mono 编辑器可继续开发使用；实际命令见运行手册，未验证的新命令不记为通过。

设计目标由本目录维护，当前实现由代码和架构/runbook说明，单次证据进入 `docs/releases/`（产生报告时创建），CI 和公开 Release 是其各自状态的权威来源。

## 文档选择与待确认

新增 release plan，撤销旧索引“无需发布计划”的决定。没有退役其他文档；不创建重复架构、项目简述、API、数据库、在线运维文档，相关边界仍为离线且已有文档足够。

待确认：首发平台与渠道、Windows 图形测试设备、macOS 签名/公证条件、真人试玩反馈。工程阶段可先推进，不把这些未验证项记为完成。

## 本轮实现位置

首发分支已新增规则回归、后台 AI、输入与动画生命周期保护、帮助/离桌确认、独立字体、标准构建与 CI。实现中不等于发布完成；R7/R8/R9 仍须以目标设备、真人反馈和公开发行证据判定。

新增玩家安装/玩法说明：[player-guide.md](../player-guide.md)。没有退役文档。最新验证命令见 [runbook.md](../runbook.md)，独立包与每次构建日志位于被 Git 忽略的 `export/`，最终验收记录将单独归档。
