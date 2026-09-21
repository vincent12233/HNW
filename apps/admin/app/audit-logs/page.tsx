"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Button, DatePicker, Input, Select, Space, Table, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import type { Dayjs } from "dayjs";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsDrawer from "@/components/OpsDrawer";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import OpsToolbar from "@/components/OpsToolbar";
import { api, getApiErrorMessage } from "@/lib/api";
import { filterLoadedRows, maskOpsPhone } from "@/lib/ops-directory";
import { formatOpsDateTime, formatOpsId } from "@/lib/ops-format";
import {
  GOVERNANCE_COPY,
  UNAVAILABLE,
  sanitizeGovernanceMetadata,
} from "@/lib/ops-governance";

const { Text } = Typography;
const { RangePicker } = DatePicker;

type AuditLog = {
  id: string;
  action: string;
  resource: string;
  resourceId?: string | null;
  description?: string | null;
  metadata?: unknown;
  createdAt: string;
  actor?: {
    id: string;
    fullName?: string | null;
    phone?: string | null;
    role?: string | null;
  } | null;
};

type AuditResponse = {
  data: AuditLog[];
  total: number;
  page: number;
  pageSize: number;
};

const actionOptions = [
  "LOAN_CREATE",
  "LOAN_APPROVE_AUTO_CREDIT",
  "LOAN_REJECT",
  "LOAN_REPAY_RECORD",
  "LOAN_MARK_OVERDUE",
  "VIP_TIER_CONFIGURATION_UPDATED",
  "CLIENT_TIER_UPDATED",
  "BUSINESS_CLIENT_TIER_UPDATED",
  "BUSINESS_CUSTOMER_STATUS_UPDATE",
  "BUSINESS_IPO_ALLOCATE",
  "SUPPORT_CONVERSATION_META_UPDATE",
  "USER_STATUS_UPDATE",
  "USER_ROLE_UPDATE",
  "INSTRUMENT_CREATE",
  "INSTRUMENT_STATUS_UPDATE",
];

function actionTone(action: string) {
  if (action.includes("REJECT") || action.includes("OVERDUE") || action.includes("FAIL")) return "REJECTED";
  if (action.includes("APPROVE") || action.includes("CREATE")) return "APPROVED";
  if (action.includes("STATUS")) return "PENDING";
  return action;
}

export default function AuditLogsPage() {
  const [records, setRecords] = useState<AuditLog[]>([]);
  const [keyword, setKeyword] = useState("");
  const [resourceId, setResourceId] = useState("");
  const [action, setAction] = useState<string | undefined>();
  const [resource, setResource] = useState<string | undefined>();
  const [range, setRange] = useState<[Dayjs, Dayjs] | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [detail, setDetail] = useState<AuditLog | null>(null);
  const inflight = useRef(false);
  const filtersRef = useRef({ action, resource, resourceId, range, page, pageSize });
  useEffect(() => {
    filtersRef.current = { action, resource, resourceId, range, page, pageSize };
  });

  const loadRecords = useCallback(async (nextPage?: number, nextSize?: number) => {
    if (inflight.current) return;
    const current = filtersRef.current;
    const pageToLoad = nextPage ?? current.page;
    const sizeToLoad = nextSize ?? current.pageSize;
    inflight.current = true;
    setLoading(true);
    setError("");
    try {
      const response = await api.get<AuditResponse>("/admin/audit-logs", {
        params: {
          page: pageToLoad,
          pageSize: sizeToLoad,
          action: current.action || undefined,
          resource: current.resource || undefined,
          resourceId: current.resourceId.trim() || undefined,
          dateFrom: current.range?.[0]?.toISOString(),
          dateTo: current.range?.[1]?.toISOString(),
        },
      });
      setRecords(Array.isArray(response.data.data) ? response.data.data : []);
      setTotal(response.data.total ?? 0);
      setPage(response.data.page ?? pageToLoad);
      setPageSize(response.data.pageSize ?? sizeToLoad);
    } catch (requestError: unknown) {
      setError(getApiErrorMessage(requestError, "操作日志加载失败"));
    } finally {
      inflight.current = false;
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadRecords(1);
  }, [loadRecords]);

  const visibleRecords = useMemo(
    () =>
      filterLoadedRows(records, keyword, (record) => [
        record.actor?.fullName,
        record.actor?.role,
        record.description,
        record.action,
        record.resource,
      ]),
    [keyword, records],
  );

  const columns: ColumnsType<AuditLog> = [
    {
      title: "操作时间",
      dataIndex: "createdAt",
      width: 180,
      render: (value: string) => formatOpsDateTime(value),
    },
    {
      title: "操作人",
      width: 200,
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <Text strong className="ops-wrap-text">{record.actor?.fullName || "系统"}</Text>
          <Text type="secondary">
            {record.actor?.role || UNAVAILABLE} / {maskOpsPhone(record.actor?.phone)}
          </Text>
        </Space>
      ),
    },
    {
      title: "动作",
      dataIndex: "action",
      width: 240,
      render: (value: string) => <OpsStatusTag code={actionTone(value)} label={value} />,
    },
    { title: "对象", dataIndex: "resource", width: 140, render: (value: string) => value || UNAVAILABLE },
    {
      title: "对象 ID",
      dataIndex: "resourceId",
      width: 220,
      render: (value?: string | null) => <span className="ops-wrap-text">{formatOpsId(value)}</span>,
    },
    {
      title: "说明",
      dataIndex: "description",
      render: (value?: string | null) => <span className="ops-wrap-text">{value || UNAVAILABLE}</span>,
    },
    {
      title: "操作",
      width: 100,
      fixed: "right",
      render: (_, record) => (
        <Button size="small" aria-label={`查看 ${record.action} 详情`} onClick={() => setDetail(record)}>
          详情
        </Button>
      ),
    },
  ];

  const metadataRows = sanitizeGovernanceMetadata(detail?.metadata);

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title="安全审计"
          crumbs={[{ title: "治理" }, { title: "安全审计" }]}
          description={`${GOVERNANCE_COPY.auditReadOnly} ${GOVERNANCE_COPY.noReplay} ${GOVERNANCE_COPY.noVip}`}
        />

        {error ? <OpsErrorState title={error} onRetry={() => void loadRecords()} /> : null}

        <OpsToolbar
          extra={
            <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void loadRecords(1)} aria-label="查询审计日志">
              查询
            </Button>
          }
        >
          <Input
            allowClear
            prefix={<SearchOutlined aria-hidden />}
            placeholder="服务端按对象 ID 精确查询"
            value={resourceId}
            onChange={(event) => setResourceId(event.target.value)}
            onPressEnter={() => void loadRecords(1)}
            aria-label="按对象 ID 查询审计日志"
            style={{ width: 260, maxWidth: "100%" }}
          />
          <Input
            allowClear
            placeholder="筛选已加载的操作人或说明"
            value={keyword}
            onChange={(event) => setKeyword(event.target.value)}
            aria-label="筛选已加载的审计记录"
            style={{ width: 240, maxWidth: "100%" }}
          />
          <Select
            allowClear
            showSearch
            placeholder="动作"
            value={action}
            onChange={setAction}
            aria-label="按动作筛选"
            style={{ width: 240 }}
            options={actionOptions.map((item) => ({ value: item, label: item }))}
          />
          <Select
            allowClear
            showSearch
            placeholder="对象"
            value={resource}
            onChange={setResource}
            aria-label="按对象筛选"
            style={{ width: 180 }}
            options={["loan", "customer", "ipo_application", "support_conversation", "user", "instrument"].map((item) => ({
              value: item,
              label: item,
            }))}
          />
          <RangePicker
            showTime
            value={range}
            onChange={(value) => setRange(value as [Dayjs, Dayjs] | null)}
            aria-label="按时间范围筛选"
          />
        </OpsToolbar>
        <Text type="secondary">{GOVERNANCE_COPY.loadedFilter}</Text>

        <Table<AuditLog>
          rowKey="id"
          className="ops-directory-table"
          columns={columns}
          dataSource={visibleRecords}
          loading={loading}
          scroll={{ x: 1280 }}
          onRow={(record) => ({ onClick: () => setDetail(record) })}
          pagination={{
            current: page,
            pageSize,
            total,
            showSizeChanger: true,
            showTotal: (count) => `共 ${count} 条日志`,
            onChange: (nextPage, nextSize) => void loadRecords(nextPage, nextSize),
          }}
          locale={{ emptyText: <OpsEmpty description={loading ? "正在加载审计日志" : "当前没有审计记录。"} onRetry={loading ? undefined : () => void loadRecords()} /> }}
        />
      </Space>

      <OpsDrawer title="审计详情" open={!!detail} onClose={() => setDetail(null)} width={560}>
        {detail ? (
          <Space orientation="vertical" size="middle" style={{ width: "100%" }}>
            <Text>时间：{formatOpsDateTime(detail.createdAt)}</Text>
            <Text>操作人：{detail.actor?.fullName || "系统"} · {detail.actor?.role || UNAVAILABLE}</Text>
            <Text>手机：{maskOpsPhone(detail.actor?.phone)}</Text>
            <Text>动作：{detail.action}</Text>
            <Text>对象：{detail.resource || UNAVAILABLE}</Text>
            <Text className="ops-wrap-text">对象 ID：{formatOpsId(detail.resourceId)}</Text>
            <Text className="ops-wrap-text">说明：{detail.description || UNAVAILABLE}</Text>
            <Text type="secondary">元数据（已脱敏）</Text>
            {metadataRows.length ? (
              metadataRows.map((row) => (
                <Text key={row.key} className="ops-wrap-text">
                  {row.key}：{row.value}
                </Text>
              ))
            ) : (
              <Text type="secondary">{UNAVAILABLE}</Text>
            )}
          </Space>
        ) : null}
      </OpsDrawer>
    </AdminShell>
  );
}
