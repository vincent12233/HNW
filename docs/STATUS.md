# HNW 项目状态

最后更新：2026-10-23
本轮整改起始基线：`20f4bfa`

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

## 2026-10-23 交付记录

- 分支：`codex/security-ui-2fa-2026-10-23`
- 最新提交：以 Pull Request 页面显示的 head commit 为准。
- Pull Request：[HNW #146](https://github.com/vincent12233/HNW/pull/146)
- 状态与验证结果：以 Pull Request 页面和 `main` 分支记录为准。
- 合并策略：通过 Pull Request 审查和必需检查后合并到 `main`，不直接推送或强制覆盖默认分支。

## 持续改进队列

1. 接入授权商业行情供应商及延迟、断流监控。
2. 接入真实 KYC 病毒扫描供应商。
3. Flutter integration test 基础入口、Android Emulator CI 工作流及登录、注册、提现关键校验已建立；注册、KYC、入金、下单、审核的真实 API/设备联调仍需在测试环境执行。
4. 资金、订单、幂等和撮合模块目录级覆盖率门槛已接入 API CI。
5. `/metrics`、HTTP、资金、KYC、订单、行情、WebSocket 指标、Prometheus 规则和 Grafana 基础面板已建立；生产告警接收人与通知渠道由部署环境配置。
6. Flutter、Admin 和 API 已统一接入不泄露 PII 的错误采集、API 接收端、二次脱敏、指标及可选 HTTPS webhook 转发；正式接收凭据在部署环境配置。
7. CMS 草稿、定时发布、自动失效、版本递增、历史回滚和英文必填法律内容校验已完成，并提供 Admin 发布管理界面。
8. 拆分超大 Flutter 页面、后台页面、API 服务和 App Content 默认内容。
9. PostgreSQL 与私有对象恢复演练脚本及 JSON 校验报告已建立；正式环境仍需按计划执行并归档报告。
10. 保存 CodeQL SARIF 或启用 GitHub Code Scanning，并配置依赖和 secret scanning。
11. 完成 Android/iOS release 专用权限、签名和包标识检查。

## 验证记录要求

每次发布记录提交号、命令、退出码、环境、时间和证据位置。旧提交的结果不能代表当前提交。

详细结构性工作见 `docs/ARCHITECTURE_IMPROVEMENT_BACKLOG.md`。
