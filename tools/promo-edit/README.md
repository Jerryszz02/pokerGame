# PokerGame 宣传片剪辑工程

基于 PokerGame **v1.4.0 / `42e62f83f9b2c439eb636ac86195312e49604af0`** 的当前游戏实录。Remotion / React / npm 依赖仅用于此剪辑目录，不进入 Godot 游戏运行时。剪辑、标题、裁切与声音包络在 `src/Films.tsx`、`src/Shot.tsx` 和 `src/Design.tsx` 中。

R2 根据用户反馈强化三个横版标题：中心弹出的斜横幅、侧入大字与更大、更高对比的章节标题。`OpeningChoice` 使用同步原片窗口显示手牌和按钮；Shorts 继续采用原 R0 成片。范围与版本证据见 [R2 制作记录](../../docs/promo-review/revision-R2-notes.md)，新增验收门槛见 [R2 补充标准](../../docs/promo-review/rubric-R2-addendum.md)。

Store / Xiaohongshu 的 [R3 修复](../../docs/promo-review/revision-R3-notes.md)将设置标题拆为两行，并把中文字幕底板完整移入独立字幕区，避免遮挡人数箭头与盲注数值。采用轮次、最终 SHA 和独立审核结果以[交付清单](../../docs/promo-review/README.md)为准。

| Composition / 成片文件 | 规格 | 内容 |
| --- | --- | --- |
| `Store` / `Store.mp4` | 60 秒，1920×1080，30 fps | itch.io / YouTube 共用，英文界面与标题 |
| `Xiaohongshu` / `Xiaohongshu.mp4` | 60 秒，1920×1080，30 fps | 保留 Store 剪辑与英文标题，增加中文字幕 |
| `Bilibili` / `Bilibili.mp4` | 80 秒，1920×1080，30 fps | 中文界面与标题，无旁白 |
| `Shorts` / `Shorts.mp4` | 30 秒，1080×1920，30 fps | 英文，同手牌的决定、结果与回放，单独竖屏取景 |

## 准备素材与依赖

当前本地产出根目录为 `/Users/jerryszz/Desktop/Projects/pokerGame/export/promo/v1.4.0/production-2026-10-15/`。`raw/` 中当前使用九条 MP4：保留 R0 原七条，R1 增加两条配置页补录。来源、SHA-256、真实手牌与补录边界见 [capture-manifest.json](../../docs/promo-review/capture-manifest.json) 和 [capture-notes.md](../../docs/promo-review/capture-notes.md)：

- `en-practice-take02.mp4`、`zh-practice-take02.mp4`
- `en-tutorial-take02.mp4`、`zh-tutorial-take02.mp4`
- `hard-ai-en.mp4`、`hard-ai-zh.mp4`、`zh-replay-pickup.mp4`
- R1 补录：`config-pickup-en.mp4`、`config-pickup-zh.mp4`

这些是 Godot 图形 MovieMaker 录制、由 UI 控件驱动的游戏画面；操作指示是后期叠层。重新录制会产生不同随机牌局，不能直接套用本工程原有时间码。`prepare-assets.mjs` 只读取来源清单中的九条 MP4，逐一核对 SHA-256 后才复制；新录屏必须先审核并更新来源清单，不能套用旧文件的版本与时间码。

每次录屏使用随机生成的独立 profile 路径，避免进程 ID 重用时继承旧手牌或教程进度。隔离回归检查已接入 CI 的 `tools/verify.py`，也可从仓库根目录执行：`/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s tests/promo_capture_isolation_test.gd`。

使用 Node.js 20.11+（本次 Node.js 22.23.1）、本机 Chrome、Shotcut 自带 FFmpeg/FFprobe；Python 检测工具的接触表需要 Pillow。从仓库根目录执行：

```sh
cd tools/promo-edit
promo_out=/Users/jerryszz/Desktop/Projects/pokerGame/export/promo/v1.4.0/production-2026-10-15
promo_python=/Users/jerryszz/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3
npm ci
node prepare-assets.mjs "$promo_out/raw"
npm run lint
```

`prepare-assets.mjs` 同时复制仓库内的 Noto Sans SC、音乐和音效，并生成 `public/media/manifest.json`。Pixelify Sans 及两份字体许可证保存在工程内。`export/`、`node_modules/`、`out/` 和准备出的影音 / Noto 字体副本均被 Git 忽略；仅取得源码不能恢复原始实录或成片，交接时需另保留本地产出目录。

## 预览、导出与证据

以下命令继续在 `tools/promo-edit/` 执行，沿用上面的变量。Studio 会打印实际地址，用 Chrome 打开并选择对应 Composition；`EndCard-*` 是片尾预览。

```sh
npm run dev -- --no-open
```

在另一终端设置相同目录和变量后导出。使用新的轮次目录保存修改，不覆盖上一轮审核证据：

```sh
node render-all.mjs "$promo_out/revisions/R0"
"$promo_python" export_edit_manifest.py --output "$promo_out/revisions/R0/metadata"
"$promo_python" verify_media.py "$promo_out/revisions/R0/Store.mp4" "$promo_out/revisions/R0/Xiaohongshu.mp4" "$promo_out/revisions/R0/Bilibili.mp4" "$promo_out/revisions/R0/Shorts.mp4" --output-dir "$promo_out/revisions/R0/verification"
```

- `render-all.mjs` 以 **8 帧并发**依次导出各片，输出 H.264（4:2:0）+ AAC 48 kHz / 192 kbit/s MP4，保留 premaster、响度测量 JSON 和 mastering 日志。R1 两遍响度处理目标为 **-16 LUFS / -2.2 dBTP / LRA 11**：R0 经 AAC 编码后曾实测 **-0.93 dBTP**，略超最终 **≤ -1 dBTP** 门槛，因此增加峰值余量；最终实际数值仍以成片检测为准。FFmpeg 默认 `/Applications/Shotcut.app/Contents/MacOS/ffmpeg`，可用 `FFMPEG` 环境变量覆盖；Chrome 路径在脚本内明确指定。
- 只导出指定片：`node render-all.mjs "$promo_out/revisions/R1" Shorts`。脚本拒绝覆盖已有最终 MP4。`--reuse-premaster` 仅恢复“渲染成功、母带尚未完成”的运行，并核对源码/资产指纹与 premaster SHA 收据；缺少收据或来源改变会拒绝复用。改时间线后使用新轮次目录。本次 R0/R1 在加入收据保护之前导出，不能用该开关复用其旧中间片。
- `export_edit_manifest.py` 输出 `edit-manifest.json` 与 `Xiaohongshu.zh-CN.srt`，记录源片 SHA-256、源与成片帧段、裁切、手牌 ID 和字幕时码，并检查时间线连续性。交接各轮时将该轮 metadata 与成片一同保留。
- `verify_media.py` 输出原始 FFprobe JSON、解码日志、各音轨响度 / 真峰值 / LRA、黑场与静音区间、每 2 秒抽帧及接触表。可重复加 `--cut 4 --cut 8` 在切点前后抽帧，或用 `--no-frames` 只测技术项。它的 loudnorm **-16 / -1 / 11** 是测量参考，不改写成片。退出码 0 不代表主观审核通过。

## 审核与发布交接

独立审核按 [rubric.md](../../docs/promo-review/rubric.md) 逐片执行；R0 为初版，最多 R1–R3 三轮修改。此 README 不代表某轮已通过或已发布。发布文字与音乐 / 字体 / 音效署名见 [publishing-copy.md](../../docs/promo-review/publishing-copy.md)。

音乐与音效原文许可见 [Airport-Lounge.txt](../../assets/licenses/Airport-Lounge.txt)、[Kenney-Casino-Audio.txt](../../assets/licenses/Kenney-Casino-Audio.txt)；剪辑字体完整版权与 OFL 1.1 见 [PixelifySans-OFL.txt](licenses/PixelifySans-OFL.txt)、[NotoSansSC-OFL.txt](licenses/NotoSansSC-OFL.txt)。分发剪辑工程或字体文件时一并保留这些许可证。
