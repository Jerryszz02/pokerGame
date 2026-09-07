# 开发、验证与桌面构建

本文描述现行命令和运行机制；首发完成定义以 [release-plan.md](planning/release-plan.md) 为准。玩家安装与操作见 [player-guide.md](player-guide.md)。

## 固定引擎

标准 GDScript 构建使用 Godot 4.7.2 与同版本官方导出模板。安装脚本下载官方资源并校验 SHA-512，不替换系统已安装的编辑器。

```sh
GODOT_BIN="$(python3 tools/bootstrap_godot.py --templates)"
"$GODOT_BIN" --version
"$GODOT_BIN" --path .
```

Windows PowerShell：

```powershell
$GodotBinary = python tools/bootstrap_godot.py --templates
& $GodotBinary --path .
```

本机历史 Mono 编辑器仍在 `/Applications/Godot_mono.app/Contents/MacOS/Godot`，需要本机 .NET 配置；发布构建不依赖它。新 worktree 必须先导入，`verify.py` 和 `build_release.py` 都会执行该步骤。

## 自动检查

```sh
python3 tools/verify.py --godot "$GODOT_BIN"
python3 tools/verify.py --godot "$GODOT_BIN" --windowed
python3 tools/soak.py --godot "$GODOT_BIN"
```

`verify.py` 包含规则、10,000 手固定种子检查、后台 AI 生命周期、材质动画清理及布局检查。`--windowed` 额外执行 1280×720、1440×900、1920×1080 的菜单、帮助、设置、日志、暂停、下注、全下、结算、离桌确认和多人出局总结流程，截图写入 `/tmp/poker_audit/`。

长测默认运行 30 分钟，包装器记录提交、dirty 状态和运行资源指纹，并把日志和报告保存在 `export/evidence/`（引擎原始报告仍写入 `user://poker_stability_report.json`）；必须同时确认成功标记、退出码、帧延迟和资源曲线。`-- --seconds=15 --min-ai=1` 只用于检查脚本能否运行，不满足首发长测门。所有 UI 探针使用各自独立 profile，不能修改真实玩家战绩。

检查日志在 `export/logs/`。Godot 某些脚本错误可能返回 0，所以不能只凭退出码认定成功；包装器会检查 `ERROR`/`SCRIPT ERROR` 和成功标记。历史窗口探针曾有 1 个 ObjectDB 退出告警；新增或持续增长的对象/动画不能按历史告警放行。

## 构建候选包

```sh
python3 tools/build_release.py --godot "$GODOT_BIN" --target macos
python3 tools/build_release.py --godot "$GODOT_BIN" --target windows
```

正式构建要求干净 checkout。开发中的本地包可显式加 `--candidate`，manifest 会标记 dirty，不能作为不可变提交的发布证据。

输出：`export/packages/` 内的版本 ZIP、平台 manifest 和 SHA256SUMS；原始导出在 `export/macos/` 或 `export/windows/`。manifest 记录提交、引擎、主机、平台、哈希和原生包自检结果。构建本身不会公开发布，也不自动将 `public_release_ready` 设为 true。

原生系统上，构建脚本会把包放进独立临时目录，并使用其中的实际程序运行 `--headless -- --self-test`。这个固定内置诊断检查场景、字体、9 组人数/难度和统计幂等，使用缓存目录里的测试 profile。官方模板不开放外部脚本和路径覆盖，测试不修改这一设置。

`export_presets.cfg` 明确列出运行资源，避免仅选场景时漏掉全局 GDScript 类或动态资源。macOS 使用官方 Universal 模板；测试范围仍按实际设备声明。当前 macOS 候选包只有 ad-hoc 签名，公证/下载隔离体验未完成验证。签名配置与凭据只能在用户授权的具体发布步骤使用，不写入仓库。

## CI 与发布

`.github/workflows/desktop.yml` 在 Linux 执行 headless 检查，在 Windows/macOS 分别导出并运行实际模板自检，上传包及日志。CI artifact 不等于公开 Release，也不能代替图形设备和真人试玩。

发布前核对 R1–R9 的逐项证据、对应提交的检查和审查、签名/目标系统结果及试玩反馈。通过后受控 squash 合并，生成与合并提交对应的版本包、校验和与发行说明，公开发布后重新下载验证。不要覆盖已发布版本的包；修复使用新版本。

## 本地数据与资源

`user://poker_profile.cfg` 仅包含偏好和聚合统计。字段会按类型规范化，写入采用同目录临时文件后替换，失败由 UI 提示。用设置中的两次点击确认重置统计，不用删除文件作为普通测试流程。

美术修改先读 [art-direction.md](art-direction.md)；运行依赖由代码 `preload()` 和导出资源列表共同明确。Noto Sans SC 使用独立的 weight-400 `FontVariation`，许可位于 `assets/fonts/OFL.txt`；变量字体不能直接以最低字重作为默认界面字体。字体在主场景初始化时应用，并显式传给弹窗；不设置项目级 `theme/custom_font`，避免干净 checkout 在首次导入前读取尚不存在的字体缓存。

维护约定：修改上述命令、状态机制、导出边界或数据语义时，在同一 PR 更新本文及对应架构/验收说明。
