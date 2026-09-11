# 开发、验证与桌面及 Web 构建

本文描述现行命令和运行机制；当前源码/发布状态见[规划入口](planning/README.md)，历史首发验收门见 [release-plan.md](planning/release-plan.md)。玩家安装与操作见 [player-guide.md](player-guide.md)。

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
"$GODOT_BIN" --headless --path . -s tests/ai_benchmark.gd
```

`verify.py` 包含规则、起手范围/对手范围/收益数学与信息边界测试、练习数据/迁移及保存失败恢复、七课教程、新模式 UI、10,000 手固定种子检查、后台 AI 生命周期、材质动画清理及布局检查。`--windowed` 额外执行 1280×720、1440×900、1920×1080 的菜单、帮助、设置、日志、暂停、下注、全下、结算、离桌确认、多人出局/胜利总结、设置生效与保存失败提示流程，截图写入 `/tmp/poker_audit/`；练习产品页面另存 `/tmp/poker_practice_audit/`。

长测默认运行 30 分钟，包装器记录提交、dirty 状态和运行资源指纹，并把日志和报告保存在 `export/evidence/`（引擎原始报告仍写入 `user://poker_stability_report.json`）；必须同时确认成功标记、退出码、帧延迟和资源曲线。`python3 tools/soak.py --godot "$GODOT_BIN" -- --seconds=15 --min-ai=1` 只用于检查脚本能否运行，不满足首发长测门。所有 UI 探针使用各自独立 profile，不能修改真实玩家战绩。

`ai_benchmark.gd` 对 1/5 个对手的翻牌、转牌、河牌固定场景各记录 5 次后台工作耗时，结果写入 `export/evidence/ai-benchmark.json`；其中包含快照与轮询开销，不用于替代窗口帧延迟。

算法专项可分别运行 `tests/test_ai_strategy.gd` 和 `tests/test_ai_observations.gd`（与上面的 Godot headless 脚本命令同形）。前者覆盖 169 类起手范围、加权抽样、收益/边池、参数边界与风格差异；后者覆盖公开行动记录、快照隔离及隐藏信息不影响固定种子决策。通过标准同时包含退出码、无脚本错误及 `AI strategy tests passed.` / `AI observation tests passed.`。模型接口和局限见 [architecture.md](architecture.md)，这些检查不证明职业级棋力。

检查日志在 `export/logs/`。Godot 某些脚本错误可能返回 0，所以不能只凭退出码认定成功；包装器会检查 `ERROR`/`SCRIPT ERROR` 和成功标记。历史窗口探针曾有 1 个 ObjectDB 退出告警；新增或持续增长的对象/动画不能按历史告警放行。

## 构建候选包

```sh
python3 tools/build_release.py --godot "$GODOT_BIN" --target macos
python3 tools/build_release.py --godot "$GODOT_BIN" --target windows
```

正式构建要求干净 checkout。开发中的本地包可显式加 `--candidate`，manifest 会标记 dirty，不能作为不可变提交的发布证据。

输出：`export/packages/` 内的版本 ZIP、平台 manifest 和 SHA256SUMS；每次使用独立临时目录导出，完成后清理本次临时目录；不会读取或删除旧 `export/macos/`、`export/windows/` 内容。manifest 记录提交、引擎、主机、平台、哈希和原生包自检结果。`.gitattributes` 固定文本 LF，避免 Windows checkout 换行转换使同一提交的资源指纹不同；构建前后会检查运行资源和 checkout 未被导入器修改。构建本身不会公开发布，也不自动将 `public_release_ready` 设为 true。

原生系统上，构建脚本会把包放进独立临时目录，并使用其中的实际程序运行 `--headless -- --self-test`。这个固定内置诊断检查场景、字体、9 组人数/难度和统计幂等，使用缓存目录里的测试 profile。官方模板不开放外部脚本和路径覆盖，测试不修改这一设置。

初始窗口使用最大化模式，避免 Retina 屏幕上 1280×720 物理像素只占 640×360 逻辑点。固定分辨率探针会显式还原窗口；长测沿用玩家的启动模式。

`export_presets.cfg` 明确列出运行资源，避免仅选场景时漏掉全局 GDScript 类或动态资源。macOS 使用官方 Universal 模板；测试范围仍按实际设备声明。当前 macOS 候选包只有 ad-hoc 签名，公证/下载隔离体验未完成验证。签名配置与凭据只能在用户授权的具体发布步骤使用，不写入仓库。

`docs/.gdignore` 将验收截图和文档排除在 Godot 资源导入之外，避免干净构建为文档图片生成未跟踪的 `.import` 文件；随包 README 仍由构建脚本显式复制。

## Web 构建（itch.io 候选）

Web 导出是 itch.io 浏览器试玩的候选目标；2026-09-11 已通过本地 Godot 4.7.2 导出和 ZIP 校验，用户同日试用了本地预览且未报告问题，但完整浏览器存储/音频验收与 itch 内嵌验证仍待完成。公开页面 <https://jerryszz02.itch.io/poker-game> 仍指向外部 GitHub 下载，构建脚本不执行上传或发布。完整步骤、存储语义与人工验收表见 [itchio-release.md](itchio-release.md)。

```sh
python3 tools/build_release.py --godot "$GODOT_BIN" --target web
```

Web 预设（`export_presets.cfg` 的 `preset.2`）启用线程（`variant/thread_support=true`）、关闭 GDExtension（`variant/extensions_support=false`）与 PWA（`progressive_web_app/enabled=false`，改用 itch.io 原生隔离头）；资源根、包含/排除过滤器与桌面预设逐字一致，`index.html` 位于导出根。`project.godot` 新增 `renderer/rendering_method.web="gl_compatibility"`，桌面 `renderer/rendering_method="mobile"` 不变。`bootstrap_godot.py --templates` 额外安装线程 Web 模板 `web_debug.zip` / `web_release.zip`。

Web 包 `export/packages/PokerGame-<version>-web.zip` 由构建脚本重新打开校验：根 `index.html`、`index.js`、`index.wasm`、`index.pck`、两个 worklet 及许可证必须存在；大小门只针对 wasm，不针对 HTML。manifest 明确记录 `web_native_self_test` 与 `browser_validation` 为 “not established by this script”，且不会把 macOS 签名写到 Web 目标。

本地静态预览使用仅绑定回环的 `tools/serve_web.py`，自动添加 COOP/COEP/CORP 与正确的 wasm 内容类型：

```sh
mkdir -p /tmp/pokergame-web && unzip -o export/packages/PokerGame-<version>-web.zip -d /tmp/pokergame-web
python3 tools/serve_web.py --directory /tmp/pokergame-web --port 8060
```

浏览器存档：Web 上 Godot `user://` 落在 IndexedDB，按浏览器、设备与源（scheme+host+port）隔离；换浏览器、隐私模式、清理站点数据或阻止存储都会使存档不可用；未发现 itch.io 云存档 API；启用/关闭 itch “SharedArrayBuffer support” 可能切换源并分离既有存档。现有存档格式、版本与迁移语义不变，本轮不新增存档功能。

## CI 与发布

`.github/workflows/desktop.yml` 在 Linux 执行 headless 检查，在 Windows/macOS 分别导出并运行实际模板自检，并在 Linux 构建 Web 包、运行 `tools/test_web_release.py` 后上传包及日志。CI artifact 不等于公开 Release，也不能代替 R7 目标设备图形验证或浏览器/itch 验收。

目标系统技术验收按下节步骤记录包哈希和结果。另行收集产品体验反馈时可使用 [可选试玩记录模板](releases/playtest-template.md)；用户已将真人试玩移出 Goal。

发布前核对 R1–R7、R9 的逐项证据、对应提交的检查和审查、所选分发路径的签名/目标系统结果；R8 已取消，不要求真人反馈。通过后受控 squash 合并，生成与合并提交对应的版本包、校验和与发行说明，公开发布后重新下载验证。不要覆盖已发布版本的包；修复使用新版本。

## 目标设备与下载验证（待执行步骤）

本节是 R7/R9 的执行方法，不是测试通过记录，也不要求额外招募真人试玩者。可由开发者在对应机器执行；已有设备上的自动 UI 操作也可提供技术证据。实际结果写入 `docs/releases/`，记录 OS/架构/GPU/驱动、屏幕分辨率与缩放、提交、包来源、SHA-256、截图、日志和复验结果。公开下载的最后一次检查使用最终发布文件。

### Windows x64

1. 使用已有或借用的 Windows x64 图形电脑，优先验证拟支持的 Windows 11 版本。使用干净测试账户保留原有战绩；不需要安装 Godot、Python 或 .NET。CI 的 Windows Server headless 检查不能证明消费级桌面图形可用。
2. 在浏览器下载候选 ZIP，发布后再从公开链接下载一次；在 Downloads 内运行 `Get-FileHash .\PokerGame-1.0.0-windows-x64.zip -Algorithm SHA256`，与该版本校验和比较。用资源管理器解压到非源码目录，直接双击 EXE，记录下载、解压和首次启动提示。
3. 检查默认最大化与最小窗口、中文/花色、鼠标和键盘操作、实际音效；在屏幕支持时检查 1280×720、1440×900、1920×1080 及 100%/150% 系统缩放。未覆盖的矩阵项保留待验证，不宣称通过。
4. 按 R2/R7 检查人数/难度、完整手牌、结算/下一手、暂停和 AI 思考期间操作、返回菜单/重开、设置保存、退出再启动及离线运行；记录卡死、错误日志、设置丢失或不可达控件。可先用正式 EXE 的 `--headless -- --self-test` 辅助诊断，但它不替代可见窗口操作。
5. 虚拟机只证明该虚拟环境；Apple Silicon 上 Windows ARM 的 x64 仿真不能作为原生 x64 GPU 验收。最低支持系统/硬件按实际覆盖范围声明。

免费发布不保证零拦截：未签名 EXE 可能触发 SmartScreen，Smart App Control 或组织策略还可能直接阻止启动。记录机器上的实际防护状态和提示，不通过关闭全局防护来制造通过结果。首发前须据此决定支持范围和安装说明。[Microsoft 官方说明](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation)

### macOS

零成本路径可保留现有 ad-hoc 签名，但它不等同于 Developer ID 或 Apple 公证。需要在目标系统验证 Apple 支持的“隐私与安全性 → 仍要打开”单应用流程及实际提示，再明确披露首次启动步骤；不把签名完整性通过当作 Gatekeeper 放行，不关闭 Gatekeeper 或删除 quarantine 来替代下载验收。是否接受这条首发路径仍待用户选择。[Godot 导出说明](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html)、[Apple 打开应用说明](https://support.apple.com/en-us/102445)

若用户已有或选择购买 Apple Developer Program 会员，正式 Developer ID 路径如下（尚未配置/执行）：

1. 在本机钥匙串准备 Developer ID Application 证书和私钥；按 Godot macOS 导出配置使用 Xcode codesign，启用 hardened runtime 所需设置，禁用 Debugging entitlement。凭据保存在钥匙串或获授权的 CI secret，不写入仓库。
2. 对导出的应用完成签名并验证，封装 ZIP，使用 Xcode 的 `notarytool submit` 和已有钥匙串 profile 提交，等待 `Accepted`；失败先检查公证日志并修复。
3. 对 `.app` 使用 `stapler staple` 和 `stapler validate`；不能把票据直接 staple 到 ZIP。重新封装最终 ZIP，重新生成校验和；签名/封装会改变文件，旧哈希不可沿用。
4. 从最终公开链接用浏览器重新下载到没有该应用既有放行记录的测试环境，保留下载隔离属性，核对哈希和签名，执行 Gatekeeper 评估，再通过 Finder 正常打开。检查在线首次启动、离线启动和 R7 完整操作，记录系统提示。只通过终端启动本地导出包不算下载验证。

Developer ID 需要开发者计划资格，常规会员价格为 99 USD/年（地区价格可能不同）；不是发布到 Mac App Store 才需要这项会员。[会员费用](https://developer.apple.com/programs/enroll/)、[Developer ID](https://developer.apple.com/developer-id/)、[公证与 stapling 流程](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)。以上政策于 2026-09-07 核对，实际发布时复核。

## 本地数据与资源

`user://poker_profile.cfg` 保存版本 2 偏好和旧版历史汇总。`user://poker_practice/profile.json` 保存版本 1 进度、成就、整场结果和紧凑累计账目，`hand_<id>.json` 保存完整牌谱。旧汇总首次导入后独立显示，不反推牌谱或成就。

最多保留 1000 手完整牌谱。到达容量后，进入“牌局记录”选择一手并确认删除，再重试保存；删除完整牌谱不减累计统计或成就。紧凑账目保留去重键和筛选所需数据，随手数增长，不含逐动作帧。设置中的“重置历史汇总”仅清空旧版汇总，需二次确认，不清空新账目。

写入使用同目录临时文件后替换；手牌文件和元数据分步落盘，元数据失败可从已写入手牌恢复。保存失败保留内存中的待提交记录，并在结算/记录页提供重试。离开未完成牌桌会确认并单列提前离桌；退出程序会丢失尚未成功保存的内存更新。新版本元数据禁止旧格式覆盖；单条损坏牌谱会跳过并提示，其余仍可读取。不要用真实玩家目录进行故障注入。

新增专项检查（完整检查仍推荐 `verify.py`）：

```sh
"$GODOT_BIN" --headless --path . -s tests/practice_data_test.gd
"$GODOT_BIN" --headless --path . -s tests/tutorial_test.gd
"$GODOT_BIN" --headless --path . -s tests/practice_ui_probe.gd
"$GODOT_BIN" --path . -s tests/practice_ui_probe.gd
```

数据和 UI 专项测试使用系统缓存目录下带唯一后缀的隔离目录。测试日志需同时检查成功标记、退出码及 `SCRIPT ERROR`；不能只看退出码。

美术修改先读 [art-direction.md](art-direction.md)；运行依赖由代码 `preload()` 和导出资源列表共同明确。Noto Sans SC 使用独立的 weight-400 `FontVariation`，许可位于 `assets/fonts/OFL.txt`；变量字体不能直接以最低字重作为默认界面字体。字体在主场景初始化时应用，并显式传给弹窗；不设置项目级 `theme/custom_font`，避免干净 checkout 在首次导入前读取尚不存在的字体缓存。

维护约定：修改上述命令、状态机制、导出边界或数据语义时，在同一 PR 更新本文及对应架构/验收说明。


## 中英文与音频

语言方案与本轮验收见 [中英文与音频记录](planning/bilingual-audio-plan.md)。`assets/translations/poker.csv` 是翻译源；编辑后需运行 Godot import，再验证两个语言资源进入 Windows、macOS 和 Web 三个导出预设。`poker_profile.cfg` 中的 `language` 为 `system / zh_CN / en`；旧设置默认跟随系统，语言不改变牌局规则或玩家数据 ID。

音频来自项目本地 `assets/audio/`，运行时不访问素材网站。`GameAudio` 节点在 UI 重建时保留，负责背景循环与动作音效；音乐和音效音量分别保存。Web 导出已有构建验证；首次输入解锁逻辑通过不代表浏览器音频与 itch 内嵌已完成验收。来源、署名和许可证位于 `THIRD_PARTY_NOTICES.md` 与 `assets/licenses/`，构建脚本会复制许可证到发行包。

```sh
"$GODOT_BIN" --headless --path . -s tests/localization_test.gd
"$GODOT_BIN" --headless --path . -s tests/localization_ui_probe.gd
"$GODOT_BIN" --headless --path . -s tests/audio_test.gd
```

headless 音频检查验证资源、循环、音量独立性和输入解锁逻辑；实际扬声器听感、背景音乐循环接缝需单独试听。

The two generated `assets/translations/poker.*.translation` resources are tracked because startup loading and release fingerprints require them before the first import. After editing the CSV, import with the pinned Godot version and commit the regenerated resources together.
