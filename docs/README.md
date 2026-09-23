# 文档入口

本页是仓库文档的唯一入口。上线、联调和验收以“当前权威文档”为准；阶段记录用于理解历史决策，不应单独作为发布依据。

## 当前权威文档

- [生产部署说明](生产部署说明.md)：服务器、PostgreSQL、Nginx、API 和后台部署。
- [本地启动与联调](本地启动与联调.md)：无 Docker 的开发环境。
- [上线准备与验收](上线准备与验收.md)：发布门槛和阻断项。
- [交付验收清单](交付验收清单.md)：交付前逐项确认。
- [客户 APP 发布配置](客户APP发布配置.md)：Android/iOS 构建配置。
- [运营流程说明](运营流程说明.md)：角色和业务流程。
- [移动端双端同步说明](移动端双端同步说明.md)：Android/iOS 同步要求。
- [APP 设计系统](APP_DESIGN_SYSTEM.md)：客户端视觉和交互规范。
- [App 内容端到端矩阵](APP_CONTENT_END_TO_END_MATRIX.md)：App、API、超级管理员内容键映射。

## 架构与审计参考

- [项目交付总览](项目交付总览.md)
- [App Content 目标架构](APP_CONTENT_TARGET_ARCHITECTURE.md)
- [APP ↔ API ↔ Admin 差距矩阵](APP_BACKEND_ADMIN_GAP_MATRIX.md)
- [APP UI/UX 审计](APP_UI_UX_AUDIT.md)
- [最终验收审计](FINAL_ACCEPTANCE_AUDIT.md)

这些文档记录审计时点。代码、自动测试和当前权威文档发生冲突时，以代码和自动测试为准，并更新文档。

## 阶段记录

以下文件记录已完成的阶段工作，保留用于追溯，不作为独立发布指南：

- `APP_CONTENT_PHASE_11A.md`、`APP_CONTENT_PHASE_11B.md`
- `APP_CONTENT_PHASE_12_ADMIN.md`、`APP_CONTENT_PHASE_13_CLIENT.md`
- `APP_CONTENT_CMS_AUDIT.md`
- `APP_NAVIGATION_CLEANUP.md`
- `HOME_UI_UX_UPGRADE.md`、`MARKETS_UI_UX_UPGRADE.md`
- `TRADE_UI_UX_UPGRADE.md`、`PORTFOLIO_UI_UX_UPGRADE.md`
- `PROFILE_UI_UX_UPGRADE.md`
- `FINAL_BLOCKER_REMEDIATION.md`
- `UI与KYC更新说明.md`

## 验证入口

- macOS/Linux：`./scripts/verify-all.sh`
- Windows：`scripts/verify-all.ps1`
- OrbStack/Docker：`compose.local-test.yaml`
- GitHub Actions：`.github/workflows/`
