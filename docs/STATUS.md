# HNW 项目状态

最后更新：2026-10-26
本轮生产加固起始基线：`6bad50399e30b604eae8f186937529cc23cafd5f`

本文件是当前项目状态的唯一入口；其他带日期的审计和交付文档仅作历史记录。

## 已完成基础

- API、后台、Flutter 的 lint/build/test CI。
- API 请求 ID、统一异常响应、健康探针、Redis 限流和账务幂等键。
- 生产密钥、HTTPS、CORS、私有文件与扫描地址校验。
- 生产启动拒绝开发用 Yahoo 行情提供商和本地病毒扫描 stub。
- API CI 保存覆盖率报告 artifact，并执行全局覆盖率回退门槛（语句 48%、分支 40%、函数 38%、行 48%）。
- Docker Desktop/Compose 本地联调环境，API、五个后台、PostgreSQL、Redis 健康检查全部通过。
- Admin 构建不再依赖 Google Fonts 网络，生产构建可在离线/受限网络环境完成。
- Flutter CI 生成并上传 `coverage/lcov.info`。
- Flutter 开发规则、响应式断点、统一敏感凭证存储边界和架构回退门槛已建立。
- API lint 已完成自动格式化整理，当前无 lint warning。
- 后台员工首次登录 Google Authenticator 绑定、短时绑定挑战、恢复码登录和防重放校验已完成。
- 后台验证器重置采用分级权限：超级管理员仅可重置管理员，管理员仅可重置自己创建的业务员；重置同时撤销目标员工现有会话并写入审计日志。
- `/metrics` 支持私网访问或独立 Bearer Token，生产启动校验会拒绝弱 Token、占位 Token 和复用的应用密钥。
- 后台登录、团队管理、仪表盘与客户端响应式 UI/UX 已完成本轮优化；交易参数、交易执行、客户注册和存款方式保持不变。
- refresh token 已增加单次使用、SHA-256 摘要留痕和并发重放拒绝；客户登录凭据与页面步骤未改变。
- 关键 Flutter 页面已覆盖 320/390/768 宽度视觉证据，PWA 覆盖手机与桌面，后台保留响应式与失败状态契约。
- 软件供应链 CI 已包含 SBOM、秘密扫描及 HIGH/CRITICAL 漏洞门禁，并保存 90 天提交绑定证据。
- 容量与恢复演练报告均绑定完整提交 SHA；恢复报告包含备份校验和及资金快照对账。
- 企业验收清单区分 `repositoryComplete`、`environmentComplete`、`externalComplete`，拒绝旧 SHA、缺失或模拟证据。

## 2026-10-26 本地验证中的交付

- 分支：`codex/hnw-production-hardening-2026-10-26`
- 基线：`6bad50399e30b604eae8f186937529cc23cafd5f`
- 已完成聚焦验证：认证模块 11 个测试套件 / 61 项测试、API lint/build、33 项 Node 运维契约、恢复演练脚本测试、GitHub 治理 fixture 测试、Admin 154 项测试、Flutter Web release 构建及 PWA 8 项浏览器测试。
- 最终完整验证、PR、远端 CI、合并及治理状态必须以本分支后续对应 SHA 的实际证据为准。

## 2026-10-23 交付记录

- 分支：`codex/security-ui-2fa-2026-10-23`
- 最新提交：以 Pull Request 页面显示的 head commit 为准。
- Pull Request：[HNW #146](https://github.com/vincent12233/HNW/pull/146)
- 状态与验证结果：以 Pull Request 页面和 `main` 分支记录为准。
- 合并策略：通过 Pull Request 审查和必需检查后合并到 `main`，不直接推送或强制覆盖默认分支。

## 持续改进队列

1. 签约并接入授权商业行情供应商，完成许可证、延迟、断流和生产回退证据。
2. 签约并接入真实 KYC/文件扫描供应商，完成回调签名、失败重试及数据处理协议证据。
3. 接入真实经纪商/交易所与清算通道，完成沙箱、认证、对账和生产准入证据；当前仓库内成交不能代表外部交易所成交。
4. Flutter integration test 基础入口、Android Emulator CI 工作流及登录、注册、提现关键校验已建立；注册、KYC、入金、下单、审核的真实 API/设备联调仍需在测试环境执行。
5. 生产告警接收人、通知渠道、容量压测、恢复演练和零差异对账须在真实隔离环境执行并归档。
6. 完成 Android/iOS 正式签名、商店账户、隐私披露及真机发布验收。

## 验证记录要求

每次发布记录提交号、命令、退出码、环境、时间和证据位置。旧提交的结果不能代表当前提交。

仓库代码能够完成的是自动化能力和安全门禁；服务商合同、交易/清算准入、生产凭据、法律批准、生产基础设施和真机结果必须由真实外部证据补齐，不能由代码或 fixture 替代。

详细结构性工作见 `docs/ARCHITECTURE_IMPROVEMENT_BACKLOG.md`。
