"use client";
import { useEffect, useMemo, useRef, useState } from "react";
import { Button, Descriptions, Form, Input, Popconfirm, Select, Space, Table, Tag, Tooltip, Typography, message } from "antd";
import { HistoryOutlined, PlusOutlined, ProfileOutlined, ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import AdminShell from "@/components/AdminShell";
import InvitePoolButton from "@/components/InvitePoolButton";
import KycReviewList from "@/components/KycReviewList";
import KycReviewModal from "@/components/KycReviewModal";
import OpsDrawer from "@/components/OpsDrawer";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsModal from "@/components/OpsModal";
import OpsMoney from "@/components/OpsMoney";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import OpsToolbar from "@/components/OpsToolbar";
import ScopedEditButton from "@/components/ScopedEditButton";
import { api, getApiErrorMessage } from "@/lib/api";
import {
  KYC_REVIEW_COPY,
  acquireReviewLock,
  buildKycReviewBody,
  canSubmitKycReview,
  collectPreviewGaps,
  partialPreviewMessage,
  releaseReviewLock,
  type KycDecision,
  type KycFilePreview,
  type KycSubmissionView,
} from "@/lib/kyc-review";
import {
  DIRECTORY_SCOPE_COPY,
  LOADED_FILTER_CAPTION,
  accountStatusLabel,
  filterLoadedRows,
  maskOpsPhone,
  useDebouncedValue,
} from "@/lib/ops-directory";
import { formatOpsDateTime, OPS_TABLE_PAGINATION } from "@/lib/ops-format";
import { loadTeamRecords } from "@/lib/team-records";
import { vipTierLabel } from "@/lib/vip";

type Staff = {
  id: string;
  fullName: string;
  role: string;
  status: string;
  createdAt?: string;
  businessProfile?: { employeeNo: string; isActive?: boolean };
  vipClientCount?: number;
  _count?: { assignedCustomers: number; createdBusinessUsers: number };
};

type TeamCustomer = {
  id: string;
  customerNo?: string | null;
  fullName: string;
  phone?: string | null;
  status: string;
  createdAt?: string;
  clientTier?: string | null;
  ownerStaffId?: string;
  ownerStaffName?: string;
  account?: {
    accountNumber?: string;
    cashBalance?: string | number;
  } | null;
};

const EMPTY_KYC_FILES = {
  front: null,
  back: null,
  selfie: null,
  signature: null,
} as { front: KycFilePreview | null; back: KycFilePreview | null; selfie: KycFilePreview | null; signature: KycFilePreview | null };

const VIEW_TITLES: Record<string, string> = {
  customers: "客户资料",
  deposits: "客户入金",
  withdrawals: "客户提现",
  positions: "客户持仓",
  orders: "客户订单",
  trades: "客户成交",
  kyc: "KYC 审核",
};

export default function TeamPage() {
  const [view, setView] = useState("team");
  const [rows, setRows] = useState<Staff[]>([]);
  const [role, setRole] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [open, setOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState("");
  const [form] = Form.useForm();
  const [selectedId, setSelectedId] = useState("");
  const [records, setRecords] = useState<Record<string, unknown>[]>([]);
  const [refreshNonce, setRefreshNonce] = useState(0);
  const [reviewing, setReviewing] = useState<KycSubmissionView | null>(null);
  const [kycFiles, setKycFiles] = useState(EMPTY_KYC_FILES);
  const [fileLoading, setFileLoading] = useState(false);
  const [reviewNote, setReviewNote] = useState("");
  const [kycPreviewError, setKycPreviewError] = useState("");
  const previewGeneration = useRef(0);
  const reviewLock = useRef(false);
  const [reviewSaving, setReviewSaving] = useState(false);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [historyRows, setHistoryRows] = useState<Array<{
    id: string;
    businessName: string;
    previousManagerName: string | null;
    newManagerName: string | null;
    reason: string;
    createdAt: string;
    clientCountAtChange: number;
  }>>([]);
  const [keyword, setKeyword] = useState("");
  const [statusFilter, setStatusFilter] = useState("ALL");
  const [detailStaff, setDetailStaff] = useState<Staff | null>(null);
  const [detailCustomer, setDetailCustomer] = useState<TeamCustomer | null>(null);
  const debouncedKeyword = useDebouncedValue(keyword);

  async function load() {
    setLoading(true);
    setError("");
    try {
      const [me, team] = await Promise.all([api.get("/auth/me"), api.get("/team")]);
      setRole(me.data.role);
      setRows(team.data);
    } catch {
      setError("团队信息加载失败，请刷新重试。");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    const syncView = (event?: Event) => {
      const target =
        event instanceof CustomEvent && typeof event.detail === "string"
          ? event.detail
          : window.location.search;
      setView(
        new URLSearchParams(target.startsWith("?") ? target : target.split("?")[1] || "").get("view") ||
          "team",
      );
    };
    syncView();
    window.addEventListener("popstate", syncView);
    window.addEventListener("admin-navigation", syncView);
    void load();
    return () => {
      window.removeEventListener("popstate", syncView);
      window.removeEventListener("admin-navigation", syncView);
    };
  }, []);

  useEffect(() => {
    if (view === "team" || !rows.length) {
      setRecords([]);
      return;
    }
    let active = true;
    setRecords([]);
    setLoading(true);
    setError("");
    const staff = selectedId ? rows.filter((row) => row.id === selectedId) : rows;
    const fetchRecords = async () => {
      const combined: Record<string, unknown>[] = [];
      for (let offset = 0; offset < staff.length; offset += 5) {
        if (!active) return;
        const batch = await Promise.all(
          staff.slice(offset, offset + 5).map(async (member) => {
            const items = await loadTeamRecords(async (page) => {
              const { data } = await api.get(`/team/${member.id}/${view}`, {
                params: view === "orders" ? { page, pageSize: 100 } : undefined,
              });
              return data;
            }, () => active);
            return items.map((item: Record<string, unknown>) => ({
              ...item,
              ownerStaffId: member.id,
              ownerStaffName: member.fullName,
            }));
          }),
        );
        combined.push(...batch.flat());
      }
      if (active)
        setRecords(
          combined.sort(
            (a, b) => Number(b.status === "PENDING") - Number(a.status === "PENDING"),
          ),
        );
    };
    fetchRecords()
      .catch(() => {
        if (active) setError("客户业务数据加载失败，请重试。未展示不完整的汇总结果。");
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [selectedId, view, refreshNonce, rows]);

  const clearReview = () => {
    if (reviewLock.current) return;
    previewGeneration.current++;
    setReviewing(null);
    setKycFiles(EMPTY_KYC_FILES);
    setReviewNote("");
    setKycPreviewError("");
  };

  async function loadKycEvidence(record: KycSubmissionView) {
    const generation = ++previewGeneration.current;
    setFileLoading(true);
    setKycPreviewError("");
    setKycFiles(EMPTY_KYC_FILES);
    const fetchSide = (side: string) =>
      api.get<KycFilePreview>(`/team/${record.ownerStaffId}/kyc/${record.id}/file?side=${side}`).then(({ data }) => data);
    try {
      const results = await Promise.allSettled([
        fetchSide("front"),
        record.backFileName ? fetchSide("back") : Promise.resolve(null),
        record.hasSelfie ? fetchSide("selfie") : Promise.resolve(null),
        record.hasSignature ? fetchSide("signature") : Promise.resolve(null),
      ]);
      const [front, back, selfie, signature] = results;
      if (front.status !== "fulfilled")
        throw front.status === "rejected" ? front.reason : new Error("证件正面不可用");
      if (generation !== previewGeneration.current) return;
      setKycFiles({
        front: front.value,
        back: back.status === "fulfilled" ? back.value : null,
        selfie: selfie.status === "fulfilled" ? selfie.value : null,
        signature: signature.status === "fulfilled" ? signature.value : null,
      });
      const unavailable = collectPreviewGaps({
        backRequested: Boolean(record.backFileName),
        backFailed: back.status === "rejected",
        selfieRequested: Boolean(record.hasSelfie),
        selfieFailed: selfie.status === "rejected",
        signatureRequested: Boolean(record.hasSignature),
        signatureFailed: signature.status === "rejected",
      });
      if (unavailable.length) setKycPreviewError(partialPreviewMessage(unavailable));
    } catch (failure: unknown) {
      if (generation !== previewGeneration.current) return;
      const detail = getApiErrorMessage(failure, "");
      setKycPreviewError(detail || KYC_REVIEW_COPY.previewError);
    } finally {
      if (generation === previewGeneration.current) setFileLoading(false);
    }
  }

  async function openKycReview(record: KycSubmissionView) {
    if (reviewLock.current) return;
    setReviewing(record);
    setReviewNote(record.reviewNote || "");
    await loadKycEvidence(record);
  }

  async function reviewKyc(decision: KycDecision) {
    if (
      !reviewing ||
      !reviewing.ownerStaffId ||
      !canSubmitKycReview({
        status: reviewing.status,
        hasFrontFile: Boolean(kycFiles.front),
        fileLoading,
        saving: reviewSaving,
        decision,
        note: reviewNote,
      })
    )
      return;
    if (!acquireReviewLock(reviewLock)) return;
    setReviewSaving(true);
    try {
      await api.patch(`/team/${reviewing.ownerStaffId}/kyc`, buildKycReviewBody(reviewing.id, decision, reviewNote));
      message.success(decision === "APPROVED" ? KYC_REVIEW_COPY.approveSuccess : KYC_REVIEW_COPY.rejectSuccess);
      previewGeneration.current++;
      setReviewing(null);
      setKycFiles(EMPTY_KYC_FILES);
      setReviewNote("");
      setKycPreviewError("");
      setRefreshNonce((value) => value + 1);
    } catch (failure: unknown) {
      const detail = getApiErrorMessage(failure, "");
      message.error(detail || KYC_REVIEW_COPY.reviewFailure);
    } finally {
      releaseReviewLock(reviewLock);
      setReviewSaving(false);
    }
  }

  async function loadHistory() {
    setHistoryOpen(true);
    setHistoryLoading(true);
    try {
      const { data } = await api.get("/team/assignment-history");
      setHistoryRows(data);
    } catch {
      setHistoryOpen(false);
      message.error("归属历史加载失败");
    } finally {
      setHistoryLoading(false);
    }
  }

  async function create(values: { employeeNo: string; fullName: string; password: string }) {
    setSaving(true);
    try {
      await api.post("/team", values);
      setOpen(false);
      form.resetFields();
      message.success("账号创建成功");
      await load();
    } catch (e: unknown) {
      const failure = e as { response?: { data?: { message?: string | string[] } } };
      const detail = getApiErrorMessage(failure, "");
      message.error(detail || "创建失败");
    } finally {
      setSaving(false);
    }
  }

  async function removeStaff(row: Staff) {
    setDeleting(row.id);
    try {
      await api.delete(`/team/${row.id}`);
      if (selectedId === row.id) setSelectedId("");
      message.success("账号已删除，登录权限已撤销");
      await load();
    } catch (error: unknown) {
      const detail = (error as { response?: { data?: { message?: string } } }).response?.data?.message;
      message.error(detail || "删除失败，请重试");
    } finally {
      setDeleting("");
    }
  }

  const hasFilters = keyword.trim() !== "" || statusFilter !== "ALL";
  const filteredStaff = useMemo(
    () =>
      filterLoadedRows(
        rows.filter((row) => (statusFilter === "ALL" ? true : row.status === statusFilter)),
        debouncedKeyword,
        (row) => [row.fullName, row.businessProfile?.employeeNo, row.role, row.status],
      ),
    [debouncedKeyword, rows, statusFilter],
  );
  const customerRows = records as TeamCustomer[];
  const customersHaveTier = customerRows.some((row) => row.clientTier);
  const filteredCustomers = useMemo(
    () =>
      filterLoadedRows(
        customerRows.filter((row) => (statusFilter === "ALL" ? true : row.status === statusFilter)),
        debouncedKeyword,
        (row) => [
          row.fullName,
          row.customerNo,
          row.id,
          row.phone,
          maskOpsPhone(row.phone, ""),
          row.ownerStaffName,
          row.account?.accountNumber,
        ],
      ),
    [customerRows, debouncedKeyword, statusFilter],
  );

  const title =
    view === "team" ? (role === "ADMIN" ? "管理员管理" : "我的业务员") : VIEW_TITLES[view] || "团队";
  const scopeCopy =
    view === "team"
      ? role === "ADMIN"
        ? DIRECTORY_SCOPE_COPY.adminTeam
        : DIRECTORY_SCOPE_COPY.managerTeam
      : view === "customers"
        ? "客户列表按当前登录角色的服务端范围返回。业务员转移后客户仍归属原业务员。"
        : undefined;

  return (
    <AdminShell>
      <div className="ops-directory-panel">
        <OpsPageHeader
          title={title}
          crumbs={[{ title: role === "ADMIN" ? "治理与人员" : "团队" }, { title }]}
          description={
            view === "kyc" ? (
              <>
                {KYC_REVIEW_COPY.description} 管理员通过所属业务员接口审核，不使用业务员待审接口。
              </>
            ) : (
              scopeCopy
            )
          }
          extra={
            <Space wrap>
              <Button
                icon={<ReloadOutlined />}
                aria-label={view === "team" ? "刷新团队列表" : "刷新客户业务数据"}
                onClick={() => (view === "team" ? void load() : setRefreshNonce((value) => value + 1))}
                loading={loading}
              >
                刷新
              </Button>
              {view === "team" && role === "MANAGER" ? (
                <Button
                  icon={<HistoryOutlined aria-hidden />}
                  aria-label="查看本团队归属历史"
                  onClick={() => void loadHistory()}
                >
                  归属历史
                </Button>
              ) : null}
              {view === "team" ? (
                <Button type="primary" icon={<PlusOutlined />} disabled={!role} onClick={() => setOpen(true)}>
                  {role === "ADMIN" ? "创建管理员" : "创建业务员"}
                </Button>
              ) : null}
            </Space>
          }
        />
        {error && view !== "kyc" ? <OpsErrorState title={error} onRetry={() => (view === "team" ? void load() : setRefreshNonce((value) => value + 1))} /> : null}
        {view !== "team" ? (
          <OpsToolbar>
            <Typography.Text>业务员</Typography.Text>
            <select
              value={selectedId}
              onChange={(e) => setSelectedId(e.target.value)}
              aria-label="按业务员筛选"
              style={{ minWidth: 220, padding: 8, borderRadius: 8, border: "1px solid #d9d9d9" }}
            >
              <option value="">全部业务员</option>
              {rows.map((r) => (
                <option key={r.id} value={r.id}>
                  {r.fullName}（{r.businessProfile?.employeeNo}）
                </option>
              ))}
            </select>
            <Typography.Text type="secondary">
              共 {records.length} 条 · 待处理 {records.filter((record) => record.status === "PENDING").length} 条
            </Typography.Text>
          </OpsToolbar>
        ) : (
          <>
            <OpsToolbar
              extra={
                hasFilters ? (
                  <Button
                    aria-label="清除筛选"
                    onClick={() => {
                      setKeyword("");
                      setStatusFilter("ALL");
                    }}
                  >
                    清除筛选
                  </Button>
                ) : null
              }
            >
              <Input
                allowClear
                prefix={<SearchOutlined />}
                placeholder="搜索已加载的姓名或员工号"
                value={keyword}
                onChange={(event) => setKeyword(event.target.value)}
                aria-label="搜索已加载团队成员"
                style={{ width: 280, maxWidth: "100%" }}
              />
              <Select
                aria-label="按状态筛选已加载结果"
                value={statusFilter}
                style={{ width: 140 }}
                onChange={setStatusFilter}
                options={[
                  { value: "ALL", label: "全部状态" },
                  { value: "ACTIVE", label: "正常" },
                  { value: "SUSPENDED", label: "已暂停" },
                  { value: "DISABLED", label: "已停用" },
                ]}
              />
            </OpsToolbar>
            <p className="ops-loaded-filter-caption">{LOADED_FILTER_CAPTION}</p>
          </>
        )}
        {view === "team" ? (
          <Table<Staff>
            rowKey="id"
            className="ops-directory-table"
            loading={loading}
            dataSource={filteredStaff}
            tableLayout="fixed"
            scroll={{ x: 1100 }}
            pagination={OPS_TABLE_PAGINATION}
            locale={{
              emptyText: (
                <OpsEmpty description={hasFilters ? "没有匹配的已加载结果" : "暂无团队成员"} />
              ),
            }}
            columns={[
              {
                title: "员工号",
                render: (_, r) => <span className="ops-id">{r.businessProfile?.employeeNo || "—"}</span>,
              },
              {
                title: "姓名",
                dataIndex: "fullName",
                render: (value: string) => (
                  <span className="ops-cell-clip" title={value}>
                    {value}
                  </span>
                ),
              },
              {
                title: "状态",
                render: (_, r) => <OpsStatusTag code={r.status} label={accountStatusLabel(r.status)} />,
              },
              {
                title: role === "ADMIN" ? "业务员数量" : "客户数量",
                render: (_, r) =>
                  role === "ADMIN" ? r._count?.createdBusinessUsers : r._count?.assignedCustomers,
              },
              ...(typeof rows[0]?.vipClientCount === "number" || role === "MANAGER"
                ? [{ title: "VIP 客户", render: (_: unknown, row: Staff) => row.vipClientCount ?? 0 }]
                : []),
              {
                title: "操作",
                fixed: "right",
                render: (_, row) => (
                  <Space wrap>
                    <Button
                      size="small"
                      icon={<ProfileOutlined />}
                      aria-label={`查看 ${row.fullName} 详情`}
                      onClick={() => setDetailStaff(row)}
                    >
                      详情
                    </Button>
                    {role === "MANAGER" ? (
                      <>
                        <ScopedEditButton
                          name={row.fullName}
                          kind="active"
                          current={row.businessProfile?.isActive ? "ACTIVE" : "SUSPENDED"}
                          endpoint={`/team/${row.id}/active`}
                          onSaved={load}
                        />
                        <ScopedEditButton name={row.fullName} kind="password" endpoint={`/team/${row.id}/password`} onSaved={load} />
                        <InvitePoolButton id={row.id} name={row.fullName} />
                      </>
                    ) : null}
                    <Popconfirm
                      title={`删除${row.role === "MANAGER" ? "管理员" : "业务员"} ${row.fullName}？`}
                      description="删除后无法登录，保留历史记录；名下有业务员或客户时需先转移归属。"
                      okText="确认删除"
                      cancelText="取消"
                      okButtonProps={{ danger: true }}
                      onConfirm={() => removeStaff(row)}
                      disabled={!!deleting}
                    >
                      <Button
                        danger
                        className="ops-danger-action"
                        loading={deleting === row.id}
                        disabled={!!deleting && deleting !== row.id}
                        aria-label={`删除 ${row.fullName}`}
                      >
                        删除
                      </Button>
                    </Popconfirm>
                  </Space>
                ),
              },
            ]}
          />
        ) : view === "kyc" ? (
          <KycReviewList
            items={records as KycSubmissionView[]}
            loading={loading}
            error={error}
            includeOwner
            busy={reviewSaving}
            onRetry={() => setRefreshNonce((value) => value + 1)}
            onOpen={openKycReview}
          />
        ) : view === "customers" ? (
          <>
            <p className="ops-loaded-filter-caption">
              {LOADED_FILTER_CAPTION} {customersHaveTier ? "" : "客户接口未返回 VIP 字段，本表不展示 VIP 列。"}
            </p>
            <Table<TeamCustomer>
              rowKey={(r, i) => String(r.id || i)}
              className="ops-directory-table"
              loading={loading}
              dataSource={filteredCustomers}
              tableLayout="fixed"
              scroll={{ x: 1280 }}
              pagination={OPS_TABLE_PAGINATION}
              locale={{ emptyText: <OpsEmpty description="暂无客户资料" /> }}
              columns={[
                {
                  title: "客户编号",
                  render: (_, row) => <span className="ops-id">{row.customerNo || row.id}</span>,
                },
                {
                  title: "客户名称",
                  dataIndex: "fullName",
                  render: (value: string) => (
                    <span className="ops-cell-clip" title={value}>
                      {value}
                    </span>
                  ),
                },
                {
                  title: "脱敏手机号",
                  render: (_, row) => maskOpsPhone(row.phone),
                },
                {
                  title: "状态",
                  render: (_, row) => <OpsStatusTag code={row.status} label={accountStatusLabel(row.status)} />,
                },
                {
                  title: "所属业务员",
                  render: (_, row) => row.ownerStaffName || "—",
                },
                ...(customersHaveTier
                  ? [
                      {
                        title: "VIP",
                        render: (_: unknown, row: TeamCustomer) => (
                          <Tag aria-label={`VIP ${vipTierLabel(row.clientTier)}`}>
                            {vipTierLabel(row.clientTier)}
                          </Tag>
                        ),
                      },
                    ]
                  : []),
                {
                  title: "现金余额",
                  align: "right" as const,
                  render: (_, row) => <OpsMoney value={row.account?.cashBalance} />,
                },
                {
                  title: "创建时间",
                  render: (_, row) => formatOpsDateTime(row.createdAt),
                },
                {
                  title: "操作",
                  fixed: "right",
                  render: (_, row) => (
                    <Tooltip title="只读详情">
                      <Button
                        size="small"
                        icon={<ProfileOutlined />}
                        aria-label={`查看客户 ${row.fullName} 详情`}
                        onClick={() => setDetailCustomer(row)}
                      />
                    </Tooltip>
                  ),
                },
              ]}
            />
          </>
        ) : (
          <Table<Record<string, unknown>>
            rowKey={(r, i) => String(r.id || r.customerId || i)}
            loading={loading}
            dataSource={records}
            scroll={{ x: 900 }}
            columns={Object.keys(records[0] || {})
              .filter((k) => !k.toLowerCase().includes("password"))
              .slice(0, 8)
              .map((key) => ({
                title: key,
                dataIndex: key,
                render: (value: unknown) =>
                  typeof value === "object" ? JSON.stringify(value) : String(value ?? "-"),
              }))}
          />
        )}
      </div>
      <OpsModal
        title={role === "ADMIN" ? "创建管理员" : "创建业务员"}
        open={open}
        onCancel={() => setOpen(false)}
        onOk={() => form.submit()}
        confirmLoading={saving}
        okText="创建"
        cancelText="取消"
      >
        <Form form={form} layout="vertical" onFinish={create}>
          <Form.Item
            name="employeeNo"
            label="员工编号"
            rules={[{ required: true }, { pattern: /^[A-Za-z0-9_-]{3,32}$/, message: "使用 3–32 位字母、数字、下划线或短横线" }]}
          >
            <Input autoComplete="off" />
          </Form.Item>
          <Form.Item name="fullName" label="姓名" rules={[{ required: true }, { min: 2, max: 100 }]}>
            <Input />
          </Form.Item>
          <Form.Item
            name="password"
            label="初始密码"
            rules={[{ required: true }, { min: 12, max: 72, message: "密码长度为 12–72 位" }]}
          >
            <Input.Password autoComplete="new-password" />
          </Form.Item>
        </Form>
      </OpsModal>
      <OpsDrawer title="本团队归属历史" open={historyOpen} onClose={() => setHistoryOpen(false)} width={520}>
        <Table
          rowKey="id"
          loading={historyLoading}
          pagination={false}
          dataSource={historyRows}
          locale={{ emptyText: "暂无与本团队有关的归属记录" }}
          columns={[
            { title: "时间", dataIndex: "createdAt", render: (value: string) => formatOpsDateTime(value) },
            { title: "业务员", dataIndex: "businessName" },
            { title: "原管理员", dataIndex: "previousManagerName", render: (value: string | null) => value || "未归属" },
            { title: "新管理员", dataIndex: "newManagerName" },
            { title: "客户数快照", dataIndex: "clientCountAtChange" },
            { title: "原因", dataIndex: "reason" },
          ]}
        />
      </OpsDrawer>
      <OpsDrawer
        title={detailStaff ? `${detailStaff.fullName} · ${detailStaff.role === "MANAGER" ? "管理员详情" : "业务员详情"}` : "详情"}
        open={!!detailStaff}
        onClose={() => setDetailStaff(null)}
        width={480}
      >
        {detailStaff ? (
          <Descriptions size="small" column={1} bordered>
            <Descriptions.Item label="员工号">
              <span className="ops-id">{detailStaff.businessProfile?.employeeNo || "—"}</span>
            </Descriptions.Item>
            <Descriptions.Item label="姓名">{detailStaff.fullName}</Descriptions.Item>
            <Descriptions.Item label="角色">
              {detailStaff.role === "MANAGER" ? "管理员" : "业务员"}
            </Descriptions.Item>
            <Descriptions.Item label="状态">
              <OpsStatusTag code={detailStaff.status} label={accountStatusLabel(detailStaff.status)} />
            </Descriptions.Item>
            <Descriptions.Item label={detailStaff.role === "MANAGER" ? "所属业务员" : "客户数量"}>
              {detailStaff.role === "MANAGER"
                ? detailStaff._count?.createdBusinessUsers ?? 0
                : detailStaff._count?.assignedCustomers ?? 0}
            </Descriptions.Item>
            {typeof detailStaff.vipClientCount === "number" ? (
              <Descriptions.Item label="VIP 客户">{detailStaff.vipClientCount}</Descriptions.Item>
            ) : null}
            <Descriptions.Item label="可见范围">
              {detailStaff.role === "MANAGER"
                ? "只读客户范围：仅限该管理员名下业务员的客户。跨团队操作请使用团队归属管理。"
                : "客户在业务员转移后仍归属原业务员。归属转移不在本页重做。"}
            </Descriptions.Item>
          </Descriptions>
        ) : null}
      </OpsDrawer>
      <OpsDrawer
        title={detailCustomer ? `${detailCustomer.fullName} · 客户详情` : "客户详情"}
        open={!!detailCustomer}
        onClose={() => setDetailCustomer(null)}
        width={480}
      >
        {detailCustomer ? (
          <Descriptions size="small" column={1} bordered>
            <Descriptions.Item label="客户编号">
              <span className="ops-id">{detailCustomer.customerNo || detailCustomer.id}</span>
            </Descriptions.Item>
            <Descriptions.Item label="客户名称">{detailCustomer.fullName}</Descriptions.Item>
            <Descriptions.Item label="脱敏手机号">{maskOpsPhone(detailCustomer.phone)}</Descriptions.Item>
            <Descriptions.Item label="状态">
              <OpsStatusTag code={detailCustomer.status} label={accountStatusLabel(detailCustomer.status)} />
            </Descriptions.Item>
            <Descriptions.Item label="所属业务员">{detailCustomer.ownerStaffName || "—"}</Descriptions.Item>
            {detailCustomer.clientTier ? (
              <Descriptions.Item label="VIP">{vipTierLabel(detailCustomer.clientTier)}</Descriptions.Item>
            ) : null}
            <Descriptions.Item label="交易账号">
              <span className="ops-id">{detailCustomer.account?.accountNumber || "—"}</span>
            </Descriptions.Item>
            <Descriptions.Item label="现金余额">
              <OpsMoney value={detailCustomer.account?.cashBalance} />
            </Descriptions.Item>
            <Descriptions.Item label="KYC 状态">当前客户资料接口未返回 KYC。</Descriptions.Item>
          </Descriptions>
        ) : null}
      </OpsDrawer>
      <KycReviewModal
        open={!!reviewing}
        submission={reviewing}
        files={kycFiles}
        fileLoading={fileLoading}
        previewError={kycPreviewError}
        note={reviewNote}
        onNoteChange={setReviewNote}
        saving={reviewSaving}
        onClose={clearReview}
        onRetryPreview={() => {
          if (reviewing) void loadKycEvidence(reviewing);
        }}
        onSubmit={reviewKyc}
      />
    </AdminShell>
  );
}
