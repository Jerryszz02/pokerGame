# Cloudflare 文字复盘服务

## 目标与边界

把现有本机文字复盘接口迁到 Cloudflare Workers 免费方案，保留游戏自动文字复盘及现有 JSON 契约。密钥保存在 Worker Secret；游戏与 Git 仓库不包含密钥。规则、雷达、数值分析继续由 Godot 本地完成。本次不更新 itch.io 游戏文件，不改动其他任务的 Devlog。

## 实施

1. 增加轻量 Worker，复用现有输入限制、固定 DeepSeek 接口和模型、输出校验、超时和无自动重试策略。
2. 用免费方案支持的 SQLite Durable Object 保存全局滚动 24 小时调用计数和有界缓存；先保留每分钟 6 次、每天 100 次新上游请求。请求前持久预留额度，失败也计数，相同请求合并。禁止用每个 Worker 实例自己的计数代替全局限额。
3. 根代理完成 Cloudflare 账号授权、Secret 配置和实际部署；仅使用免费资源。配置实际游戏 Web 来源的 CORS，桌面客户端允许无 Origin 请求。CORS 不作为身份认证，公开匿名端点依靠严格固定用途与总额度限制控制消耗。
4. 部署后更新游戏公开服务地址，运行协议、并发限额、重启持久化、失败回退、导出排除和真实游戏文字复盘验收；通过后提交并创建 PR。

## 验收

- 无密钥日志、客户端凭据、任意提示词或可变上游地址。
- 不合法/超大请求、坏来源、上游超时或错误均受控；错误不泄露上游响应内容。
- 并发与对象重启不能绕过总额度；缓存命中不消耗上游额度。
- 密钥缺失与服务不可用时保留本地复盘。
- 云端 HTTPS 健康检查与一次实际 DeepSeek 复盘通过；游戏结果确实显示文字。
- 记录实际部署 URL、版本、检查结果和免费资源范围；不把健康检查等同于完整联调。

## 2026-09-18 实施结果

- Worker 已部署到 `https://pokergame-coach.jerryszz02.workers.dev`，服务路径为 `/review`；当前版本为 `f4d3e599-74fd-4485-b70c-72951f1dbcfb`。密钥通过标准输入上传为 `DEEPSEEK_API_KEY` Secret，原私有文件未修改。
- 资源仅为一个 Worker 和一个 SQLite Durable Object，使用 Free 兼容配置；未创建或升级任何付费订阅。当前 OAuth 权限不含账单读取，因此没有把部署结果当作账户账单审计。DeepSeek 仍使用运营者账户额度。
- 标准 `npm ci`、类型检查、47 项 Worker 测试、部署打包均通过，npm audit 为零条已知漏洞。测试覆盖真实 Worker/SQLite DO 路径、相同请求合并、并发准入、滚动额度、失败计数、对象重建、缓存及过期、存储失败、超时、大小上限和输出校验，全部使用固定上游响应。
- 云端联调修复了 `redirect: error` 在 workerd 中不可用的问题：实际构造 `Request`，使用 `manual` 并拒绝所有非成功响应，不跟随重定向；测试覆盖真实 Request 构造，避免模拟 fetch 隐藏运行时限制。排查时的临时诊断日志已经移除。
- 配置上传脚本的 3 项测试、本机 Python 服务与 Godot HTTP 契约、文字复盘和教练 UI 回归均通过。Web 候选包成功导出；检查确认包含云端服务地址，不含实际密钥、私有文件、Worker 源码和依赖。
- 实机完成一手牌的 4 个决定分析，随后经真实 Cloudflare → DeepSeek 返回 HTTP 200，回放界面自动显示 3 段文字；相同数值摘要的云端缓存请求也返回 200。健康检查 200、itch.io 来源预检 204、非法输入 400、未允许来源 403。
- **网络限制仍存在**：本机直连默认域名超时。成功的实机和 HTTP 联调使用本机既有代理；探针只调整传输代理，数值分析、云端模型响应和游戏渲染均为真实流程。未宣称原生客户端会自动采用系统代理，也未完成浏览器运行验收。后续如提供自有域名，应绑定后再验证目标网络直连。
- 游戏源码已改用公开 URL；本次没有上传或发布 itch.io 游戏包，也没有恢复已暂停的 Devlog 工作。

平台依据：[SQLite Durable Objects 定价](https://developers.cloudflare.com/durable-objects/platform/pricing/)、[Worker Secret](https://developers.cloudflare.com/workers/configuration/secrets/)、[workers.dev 路由](https://developers.cloudflare.com/workers/configuration/routing/workers-dev/)。
