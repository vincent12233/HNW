# 2026-11-27 六项审计问题修复交付

## 基线与边界

- 实施基线：`8a347bfd68579a65adf84b617188c83fc1b6ffc4`，PR #191 的实际 head。
- 实施前刷新远端确认：默认分支 `main` 为 `cbee77c2c2f20ae1c4f744a06a9a479aeb0a5069`；#191 尚未合并。
- 修复分支：`codex/fix-six-audit-findings-20261127`；后续 Draft PR 以 `codex/security-audit-20261127` 为 base，依赖 #191。#191 合并后再调整 base 并重新验证。
- 本次仅六项及直接依赖的迁移、客户端契约、回归与运维配置。27 项中危依赖、AOCI 同步、外部供应商联调另行跟踪。
- 未合并 PR，未执行生产发布、回滚或数据迁移。所有数据库执行均在本机隔离 PostgreSQL 17 测试库。

## 修复及业务规则

### 密码恢复

员工身份只取认证上下文。服务层统一限制列表、消息读取/发送和签发；SUPPORT 采用固定邀请码归属、有效员工档案及 `assignedBusinessId`，并保留现有“异常分配需修复”的限制。ADMIN 保留原管理范围。外部会话编号和身份确认布尔值不授予权限。

列表直接在 SQL 过滤；单会话依据数据库保存的手机号关联客户。员工写操作先锁客户行，再重新检查归属，与现有客户转移更新同一行兼容。兑换恢复码时重新校验签发员工的当前权限：转移后旧 SUPPORT 的未使用码失效；ADMIN 签发的码仍按原权限范围处理。过期、使用次数和账号版本失效规则保留。

### 贷款还款

新增 `loan_repayments`，唯一范围为 `(loanId, requestId)`，`Idempotency-Key` 必填，8–100 个允许字符。相同键且金额/规范化备注不同返回 409；同键重试返回持久化的首次响应，后续余额变化不影响重放。

同一 Read Committed 事务内锁贷款行、检查权限/幂等/状态/欠款、写流水、更新贷款并写本库审计。超额还款拒绝，金额沿用 Decimal 两位精度。审计失败整体回滚。存量贷款可以正常还款，迁移不构造历史还款流水。

后台以 sessionStorage 保存未确认操作的键和原始内容；网络错误、关闭弹窗、刷新后继续使用原键。成功响应后清除，再次主动登记是新业务。清空浏览器存储或换浏览器会丢失本地重试上下文；操作员应先核对已有流水，不盲目重复登记。

### 冻结金额对账

保留 `FROZEN_CASH_BUY_ORDERS` 检查类型和报告接口。一个 SQL 快照内独立聚合账户的 OPEN/PARTIALLY_FILLED 买单剩余 `frozenAmount` 与 PENDING 提现 `frozenAmount`，相加后比较账户冻结额。金额以账户币种为界；空集合为零，多笔订单/提现不发生笛卡尔乘积。详情增加 `currency`、`withdrawalFrozen`，保留 `orderFrozen`。

当前提现只有 PENDING/APPROVED/REJECTED；审核通过和拒绝均清零冻结。不存在独立“支付失败/取消”状态，未新增或假设这些流转。普通买单撤单清零、部分成交按剩余冻结计算。

### IPO 申购

保持“同一账户 + 同一 IPO，所有申购状态累计最多五次”的现有规则，达到上限继续返回 `canApply:false`。使用 PostgreSQL 事务级 advisory lock，范围为账户+IPO；同事务内先重放幂等结果，再检查窗口、计数和写入。新增可空 requestId/response 字段和三字段唯一索引；历史记录保持空值。唯一应用创建入口统一经过该路径。

申购阶段本来不冻结/扣款，仍不改变；配售与缴款流程保持原事务边界。创建或响应持久化失败整体回滚。历史超过五次只在迁移中报告组数，保留申购与账务并拒绝新增，不擅自清理。

Flutter 以账户+IPO 保存非敏感请求键；并发调用及响应丢失后重试复用键，确认响应后才清除。API 新增必填 `Idempotency-Key`。旧移动版本没有此头时会收到明确 400；上线前须完成客户端分发/最低版本策略，不能无提示切换服务端。

### 设备会话

每次密码/Google 认证由服务端创建 `sessionBound=true` 的设备会话；访问、刷新、生物识别凭据均签入同一 `sid`。注册设备接口只更新已认证 sid 的显示信息，忽略客户端声称的其他设备身份。

JWT、正常 KYC 访问、WebSocket 认证及消息入口、refresh、biometricLogin 均检查主库设备状态，无正向缓存。撤销原子更新该设备行，不增加全账户 authVersion。刷新和快捷登录签发在同一设备行锁内检查；即使先完成签发，撤销提交后这些凭据也不可用。重复撤销返回成功，其他设备保持有效。已有主动全账户退出/密码重置的版本失效行为保留。

迁移将历史展示设备标为撤销，新增字段默认 false。没有 sid 的历史访问/刷新/生物识别令牌拒绝，需重新密码/Google 认证；后台 cookie 同样需要重新登录及现有 2FA。KYC_ONBOARDING、STAFF_2FA_SETUP 是受限用途凭据，不作为完整设备会话，原注册和首次 2FA 绑定流程保留。

### 发布与回滚证据

删除通用 Coolify webhook + 固定 sleep + 输入摘要即成功的路径。新增手动 `Build Immutable API Release` 工作流，从 main 构建 API，写入 commit 构建参数，发布不可变 GHCR 镜像并记录 OCI index digest、各平台 manifest digest 及 config digest（Docker image ID）。证明的是 API 服务，后台仍执行可用性检查，不声称证明后台镜像。

部署只接受本仓库 main 上成功的指定构建工作流运行，先通过 GitHub API 校验 workflow path、事件、仓库、分支及结论，再下载同一次运行的不可变 artifact，校验 head SHA 和 buildRunId。回滚只能选本仓库成功生产发布/回滚运行中 `VERIFIED` 的历史证据。过期/丢失 artifact 明确失败，不能手输 digest 绕过。

平台部署必须明确使用 `image@digest`。轮询完整活动副本清单，每个副本的 index/platform digest 和 config digest 都要属于可信构建映射，再逐副本代理读取 `/health/version` 验证 commit，最后重新核对清单未发生滚动替换。只有全部副本、提交、镜像、readiness 都通过才输出 `deployment.json`；失败只写脱敏 `failure.json`。证据包含环境、部署 ID、预期提交/摘要、逐副本实际提交/摘要、构建记录、CI run ID 和时间。

## 部署适配器前置条件（尚未完成环境验收）

当前凭据读取仓库 Actions secrets/variables 名称返回 HTTP 403，未获得 Coolify 管理端或已授权测试环境，不能核实实际配置。现有通用 webhook 不满足版本绑定。新流程缺少以下适配器时**失败关闭**，不得将环境配置缺失解释为发布成功。

由部署平台管理员提供并在测试环境验收的 HTTPS 服务：

- `DEPLOYMENT_ADAPTER_URL`：固定受信管理服务地址；`DEPLOYMENT_ADAPTER_TOKEN`：受限部署凭据。仅允许该 API 服务和目标环境，不得代理任意 URL。
- `GET /v1/capabilities`：返回 schema=1、immutableImage=true、completeReplicaInventory=true、replicaVersionProxy=true。声明必须由实际平台能力支撑，不能给通用 webhook 包一层成功响应。
- `POST /v1/deployments`：接收 environment、service=`hnw-api`、image=`ghcr.io/vincent12233/hnw-api@sha256:...`、commit、operation、requestId；必须将该不可变目标写入平台并启动部署，requestId 幂等，返回 deploymentId。
- `GET /v1/deployments/{id}`：从平台读取 environment/service/status、desiredReplicas、inventoryComplete、全部活动 replicas。每个副本包含 id、ready、platform、image、实际 digest、configDigest。清单必须包含仍承载流量的旧副本，不能只列目标版本；只有平台确认部署完成才能返回 SUCCEEDED。
- `GET /v1/deployments/{id}/replicas/{replica}/health/version`：代理到指定实际副本的版本接口，禁止用负载均衡地址或期望值代替运行值。
- 配置已有 `PRODUCTION_API_URL`、`PRODUCTION_ADMIN_URLS`，保护 `production` 和 `release-build` 环境审批，确保 GHCR 拉取权限。

适配器实现/实际 Coolify API 版本能力验证、测试环境部署和回滚、全副本切换证明均待环境权限。仓库仅提供强校验调用契约与自动化失败场景，不宣称适配器已部署。生产启用另行授权。

## 升级、迁移与回滚顺序

1. #191 合并、修复分支检查通过后，由发布负责人确认应用分发、维护窗口、数据库备份及设备重新登录公告；本任务不执行此步骤。
2. 先分发带 IPO 幂等头的移动版本、带贷款幂等头的后台。旧服务会忽略新增头，便于先升级客户端；确认最低受支持版本后再切换服务端。
3. 经独立授权执行三个前向迁移：loan_repayments → ipo_request_identity → device_sessions。迁移升级演练包含真实存量账户、流水、贷款、历史设备。设备迁移会使新服务要求历史会话重新认证，需与新 API 切换协调。
4. 用可信构建记录部署 API；逐副本校验，并验证重新登录、两设备撤销、还款和申购重试。滚动发布期间旧 API 不具备新设备校验，不能在混合版本窗口宣布撤销保障已生效；应停旧实例后统一开放新版本。
5. 保留新增表/列及实际账务记录。禁止通过回滚删除还款流水、恢复已撤销设备或反向修改客户账目。旧 API 无幂等/设备撤销保障，业务安全问题不能靠回退旧逻辑解决；优先前向修复，必要回滚需要重新评估并授权。
6. 回滚工作流只接受历史 VERIFIED 不可变镜像并重复相同核验，不执行数据库回滚。部署/回滚实际执行仍需明确授权。

## 验证记录

执行环境：Node 24、PostgreSQL 17（隔离本地容器）、Redis 隔离本地容器、Flutter 3.47.0 / Dart 3.13.0。测试与 CI 的最终统计在 Draft PR 和交付回复更新，以最终 head 为准，不使用 #191 的通过记录替代本轮结果。

已执行：API lint/build 与全量测试；真实 PG 的归属转移、并发还款/幂等/审计回滚、冻结组合、IPO 并发/历史超限/回滚、两设备撤销/刷新竞态/历史凭据；空库迁移与基线带数据升级；后台 lint、测试、类型检查与构建；发布脚本及仓库架构/发布守卫。Flutter 静态分析、全量测试与 Web 构建已通过；本轮远端检查继续跟踪。

尚未执行的环境验证：Coolify 能力查询及真实目标绑定、测试环境实际发布/回滚和 OCI 运行身份映射、多副本真实滚动切换、生产设备再认证启用演练。阻塞为部署配置读取 403、无授权测试部署环境/适配器；不绕过权限。

### 本地最终验证明细

| 检查 | 结果 |
| --- | --- |
| API `npm run lint`、`npm run build` | 通过 |
| API 全量，`HNW_VERIFY_PG=1 HNW_VERIFY_REDIS=1 npm test -- --runInBand` | 151 套件，700 通过，0 跳过 |
| 后台 `npm run lint`、`npm test`、`tsc --noEmit`、生产构建 | 155 测试通过，0 跳过；其余通过 |
| Flutter 3.47.0 `flutter analyze --no-fatal-infos` | 无问题 |
| Flutter `flutter test --no-pub` | 503 通过，45 条既有条件跳过（截图/可视化输出路径等） |
| Flutter `flutter build web --no-pub --dart-define=API_BASE_URL=https://build.invalid` | 通过；Wasm dry-run 提示第三方库兼容性，不影响 JS Web 构建 |
| `node --test scripts/tests/*.test.mjs` | 48 通过，0 跳过 |
| 空库全量迁移 | 独立 `hnw_six_fresh_test` 通过 |
| 基线 schema 带数据升级 | 独立 `hnw_six_upgrade_test`，从 `20261026190000_refresh_token_replay_protection` 到三项新迁移，通过 |
| 保护流程、架构/源码大小/客户端信息边界与页面清单、发布配置、`git diff --check` | 通过 |

本地合计 1,406 项通过，45 项条件跳过，未将迁移/构建/静态检查计作单元测试。iOS 模拟器仅由本轮 GitHub Actions 执行，Linux 本地未执行；远端结果以 Draft PR 的最终提交检查为准。
