"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Input, Select, Space, Table, Tag, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api, getApiErrorMessage } from '@/lib/api';

const { Title, Paragraph, Text } = Typography;

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
  "BUSINESS_CUSTOMER_STATUS_UPDATE",
  "BUSINESS_IPO_ALLOCATE",
  "SUPPORT_CONVERSATION_META_UPDATE",
  "USER_STATUS_UPDATE",
  "USER_ROLE_UPDATE",
  "INSTRUMENT_CREATE",
  "INSTRUMENT_STATUS_UPDATE",
];

function formatDate(value?: string | null) {
  return value ? new Date(value).toLocaleString("zh-CN") : "-";
}

function actionTag(action: string) {
  const color =
    action.includes("REJECT") || action.includes("OVERDUE")
      ? "red"
      : action.includes("APPROVE") || action.includes("CREATE")
        ? "green"
        : action.includes("STATUS")
          ? "orange"
          : "blue";
  return <Tag color={color}>{action}</Tag>;
}

export default function AuditLogsPage() {
  const [records, setRecords] = useState<AuditLog[]>([]);
  const [keyword, setKeyword] = useState("");
  const [action, setAction] = useState<string | undefined>();
  const [resource, setResource] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const filtersRef = useRef({ action, resource, keyword, page });
  useEffect(() => {
    filtersRef.current = { action, resource, keyword, page };
  });

  const loadRecords = useCallback(async (nextPage?: number) => {
    const { action: nextAction, resource: nextResource, keyword: nextKeyword, page: currentPage } =
      filtersRef.current;
    const pageToLoad = nextPage ?? currentPage;
    setLoading(true);
    setError("");

    try {
      const response = await api.get<AuditResponse>("/admin/audit-logs", {
        params: {
          page: pageToLoad,
          pageSize: 20,
          action: nextAction || undefined,
          resource: nextResource || undefined,
          resourceId: nextKeyword.trim() || undefined,
        },
      });
      setRecords(Array.isArray(response.data.data) ? response.data.data : []);
      setTotal(response.data.total ?? 0);
      setPage(response.data.page ?? pageToLoad);
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      setError(responseMessage || "操作日志加载失败");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadRecords(1);
  }, [loadRecords]);

  const visibleRecords = useMemo(() => {
    const value = keyword.trim().toLowerCase();
    if (!value) return records;
    return records.filter((record) =>
      [
        record.resourceId,
        record.description,
        record.actor?.fullName,
        record.actor?.phone,
        record.action,
        record.resource,
      ].some((field) => String(field ?? "").toLowerCase().includes(value)),
    );
  }, [keyword, records]);

  const columns: ColumnsType<AuditLog> = [
    {
      title: "操作时间",
      dataIndex: "createdAt",
      width: 180,
      fixed: "left",
      render: formatDate,
    },
    {
      title: "操作人",
      width: 180,
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{record.actor?.fullName || "系统"}</Text>
          <Text type="secondary">{record.actor?.role || "-"} / {record.actor?.phone || "-"}</Text>
        </Space>
      ),
    },
    { title: "动作", dataIndex: "action", width: 220, render: actionTag },
    { title: "对象", dataIndex: "resource", width: 140 },
    { title: "对象ID", dataIndex: "resourceId", width: 240, render: (value) => value ? <Text copyable>{value}</Text> : "-" },
    { title: "说明", dataIndex: "description", width: 260, render: (value) => value || "-" },
    {
      title: "详情",
      dataIndex: "metadata",
      render: (value) => value ? <Text code>{JSON.stringify(value)}</Text> : "-",
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>操作日志</Title>
          <Paragraph type="secondary">查看管理员、财务、客服和业务员的关键操作记录，用于核对资金、账户、IPO、贷款和客服处理过程。</Paragraph>
        </div>
        {error && <Alert type="error" title={error} showIcon />}
        <Card>
          <Space wrap style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}>
            <Space wrap>
              <Input allowClear prefix={<SearchOutlined />} placeholder="搜索对象ID、说明、操作人或手机号" value={keyword} onChange={(event) => setKeyword(event.target.value)} onPressEnter={() => loadRecords(1)} style={{ width: 340 }} />
              <Select allowClear placeholder="动作" value={action} onChange={setAction} style={{ width: 240 }} options={actionOptions.map((item) => ({ value: item, label: item }))} />
              <Select allowClear placeholder="对象" value={resource} onChange={setResource} style={{ width: 170 }} options={["loan", "customer", "ipo_application", "support_conversation", "user", "instrument"].map((item) => ({ value: item, label: item }))} />
            </Space>
            <Button icon={<ReloadOutlined />} onClick={() => loadRecords(1)} loading={loading}>查询</Button>
          </Space>
          <Table<AuditLog>
            rowKey="id"
            columns={columns}
            dataSource={visibleRecords}
            loading={loading}
            scroll={{ x: 1500 }}
            pagination={{
              current: page,
              pageSize: 20,
              total,
              showTotal: (count) => `共 ${count} 条日志`,
              onChange: (nextPage) => loadRecords(nextPage),
            }}
          />
        </Card>
      </Space>
    </AdminShell>
  );
}
