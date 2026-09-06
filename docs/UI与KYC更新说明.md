# 客户端 UI 与 KYC 更新

客户 App 采用白底、深蓝文字、蓝色主要操作按钮和账户摘要卡片。Android/iOS 共用 Flutter 实现。

- 登录、注册、KYC 选择/证件上传、自拍、签名及银行账户表单使用统一视觉样式。
- KYC 的继续/提交按钮固定在底部；照片显示用户实际选择的内容，签名由用户绘制后生成 PNG。
- 首页、行情、交易、持仓与个人中心继续使用现有服务数据；没有加入参考图中的姓名、账户金额、证件样例或行情走势。
- 银行账户在个人中心添加，保存前校验账户号码二次确认。IFSC 仍按现有后端要求必填。
- 业务员审核页面可以查看证件、自拍和签名；文件读取沿用业务员归属权限。自拍是人工审核材料，没有实现自动人脸匹配或活体检测。

## 部署顺序

1. 备份数据库，执行 `apps/api` 下的 `npm run db:migrate`，应用 `20260906000100_kyc_selfie_signature`。
2. 部署后端和管理后台，再发布配套 Flutter 客户端。新的 KYC 提交接口要求自拍及签名，旧版客户端需同步升级。
3. 现有申请的新增列允许为空，历史审核资料仍可读取。数据库中只记录私有文件标识，审核列表不暴露存储路径。
4. 反向代理请求体限制至少应允许 28 MB；证件每面最多 8 MB、自拍最多 2 MB、签名最多 1 MB。客户端提交超时为 90 秒。

没有在本次开发中连接生产数据库或执行生产迁移。

## 验证命令

- API：`npm run db:generate`、`npm run build`、`npm test -- --runInBand kyc.service.spec.ts`。
- 管理后台：`npx next typegen`、`npx tsc --noEmit`。
- 客户端：`flutter analyze`、`flutter test --no-pub`。
- 可选界面截图：`flutter test test/ui_capture_test.dart --update-goldens --dart-define=UI_CAPTURE_DIR=<绝对输出路径>`。该测试使用空账户/离线状态，不包含客户隐私数据；Windows 上使用本机字体生成预览。

实际相机权限、图库选择、后台数据库迁移和端到端审批仍应在部署前使用测试设备及测试数据库验收。
