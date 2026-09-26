# 架构持续改进清单

最后更新：2026-09-26

本清单只记录不适合在一次低风险变更中完成的结构性工作。每项必须独立提交、测试和回滚，不得以大规模重写方式合并。

## P1：客户端状态迁移

- [x] 将 `market_page.dart` 的加载、空、错误、过期和离线状态迁移到 `AsyncDataState`。
- [x] 将 `markets_page.dart`、`product_portfolio_page.dart` 和 `home_dashboard.dart` 迁移到同一状态模型。
- [x] 所有缓存展示必须包含更新时间；余额、持仓和订单不得把失败转换为零值或空列表。
- [x] 为网络切换、前后台恢复、旧请求覆盖新请求和页面销毁增加回归测试。

## P1：外部请求幂等

- [x] 提现申请支持 `Idempotency-Key`、数据库唯一约束和事务级 advisory lock。
- [x] 下单接口复用现有 client order id，并统一 `Idempotency-Key` 响应语义。
- [ ] 入金确认、提现审核、KYC 提交和管理员资金调整采用同一键格式与重放规则。
- [ ] 重放必须返回首次业务结果，不能再次冻结、扣款、通知或写审计记录。

## P1：审计与错误契约

- [x] API 错误响应包含稳定 `code` 和 `requestId`。
- [ ] 为资金、审批和权限拒绝定义集中式业务错误码表。
- [ ] 审计元数据统一记录 requestId、idempotencyKey、结果和状态版本。
- [ ] 后台审计查询支持结果、请求 ID 和幂等键过滤。

## P2：大文件拆分

- [ ] `apps/client/lib/pages/market_page.dart`：拆分状态控制、指数、列表、筛选和错误展示。
- [ ] `apps/api/src/business/business.service.ts`：拆分客户查询、分配、统计和权限域。
- [ ] `apps/api/src/app-content/app-content.defaults.ts`：按 home、market、legal、KYC、trading、support 分文件。
- [ ] `apps/admin/app/app-content/page.tsx`：拆分表单、预览、版本和发布流程。

## P2：内容治理

- [ ] 清点 `HOME_UI_UX_UPGRADE.md` 和 `MARKETS_UI_UX_UPGRADE.md` 中剩余硬编码内容。
- [ ] CMS 内容增加语言、生效时间、失效时间、发布状态、操作人和版本。
- [ ] 法律与风险内容缺失时阻止发布，不允许静默使用过期占位文本。

## P2：可观测性

- [x] 提供 `/health/live`、`/health/ready` 和 `/health/version`。
- [ ] 增加行情延迟、WebSocket 重连、KYC 扫描失败、提现失败和 5xx 指标。
- [ ] 建立告警阈值、值班负责人和故障复盘模板。
- [ ] 构建产物注入 `GIT_COMMIT` 与 `BUILD_TIME`。

## 外部依赖

以下项目没有供应商和凭据时不能在仓库内伪造完成：

- 授权商业行情供应商、使用许可、凭据和 SLA。
- 真实 KYC 病毒扫描供应商、回调协议和故障策略。
- 告警接收平台及值班人员。
- 正式法律文本和运营主体信息。
