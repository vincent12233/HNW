"use client";

import {
  CheckOutlined,
  CloseOutlined,
  CloudSyncOutlined,
  ReloadOutlined,
  SearchOutlined,
  StockOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Input,
  Popconfirm,
  Select,
  Space,
  Statistic,
  Switch,
  Table,
  Tabs,
  Tag,
  Typography,
  message,
} from "antd";
import type { ColumnsType, TablePaginationConfig } from "antd/es/table";
import { useEffect, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;

type InstrumentMasterRecord = {
  id: string;
  symbol: string;
  exchange: string;
  name: string;
  isin?: string | null;
  category?: string | null;
  lotSize: number;
  tickSize: string | number;
  displayOrder: number;
  isActive: boolean;
  updatedAt: string;
  quote?: {
    lastPrice?: string | number | null;
    asOf?: string | null;
  } | null;
};

type InstrumentMasterResponse = {
  statistics: { total: number; enabled: number; quoted: number };
  autoSync: { nse: boolean; bse: boolean };
  data: InstrumentMasterRecord[];
  total: number;
  page: number;
  pageSize: number;
};

type SyncResult = {
  totalRows: number;
  created: number;
  updated: number;
};

type ApiErrorShape = {
  response?: {
    data?: {
      message?: unknown;
    };
  };
};

function apiError(error: unknown, fallback: string) {
  const value = (error as ApiErrorShape)?.response?.data?.message;
  if (Array.isArray(value)) return value.map(String).join("，");
  return value == null ? fallback : String(value);
}

function formatPrice(value?: string | number | null) {
  if (value === null || value === undefined || Number(value) <= 0) return "-";
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 2,
  }).format(Number(value));
}

function formatDate(value?: string | null) {
  return value ? new Date(value).toLocaleString("zh-CN") : "-";
}

export default function InstrumentLibraryPage() {
  const [records, setRecords] = useState<InstrumentMasterRecord[]>([]);
  const [search, setSearch] = useState("");
  const [active, setActive] = useState<boolean | undefined>();
  const [exchange, setExchange] = useState<"NSE" | "BSE">("NSE");
  const [statistics, setStatistics] = useState<InstrumentMasterResponse["statistics"]>();
  const [autoSync, setAutoSync] = useState<InstrumentMasterResponse["autoSync"]>();
  const requestVersion = useRef(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(50);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const [enablingAll, setEnablingAll] = useState(false);
  const [error, setError] = useState("");
  const [selectedRowKeys, setSelectedRowKeys] = useState<React.Key[]>([]);

  async function loadRecords(nextPage = page, nextPageSize = pageSize) {
    const version = ++requestVersion.current;
    setLoading(true);
    setError("");
    try {
      const response = await api.get<InstrumentMasterResponse>("/admin/instruments", {
        params: {
          search: search.trim() || undefined,
          active,
          exchange,
          page: nextPage,
          pageSize: nextPageSize,
        },
      });
      if (version !== requestVersion.current) return;
      setStatistics(response.data.statistics);
      setAutoSync(response.data.autoSync);
      setRecords(Array.isArray(response.data.data) ? response.data.data : []);
      setTotal(Number(response.data.total ?? 0));
      setPage(Number(response.data.page ?? nextPage));
      setPageSize(Number(response.data.pageSize ?? nextPageSize));
      setSelectedRowKeys([]);
    } catch (requestError: unknown) {
      if (version !== requestVersion.current) return;
      setError(apiError(requestError, "股票库加载失败"));
    } finally {
      if (version === requestVersion.current) setLoading(false);
    }
  }

  useEffect(() => {
    const timer = window.setTimeout(() => {
      void loadRecords(1, 50);
    }, 0);
    return () => { window.clearTimeout(timer); requestVersion.current++; };
    // Initial server load only; filters are submitted explicitly.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [exchange]);

  async function enableAll() {
    setEnablingAll(true);
    try {
      const { data } = await api.patch<{ updated: number }>("/admin/instruments/enable-all", null, { params: { exchange } });
      message.success(`已启用 ${data.updated} 只股票`);
      await loadRecords(1, pageSize);
    } catch (error) { message.error(apiError(error, "全部启用失败，请重试")); }
    finally { setEnablingAll(false); }
  }

  async function syncExchange(exchange: "NSE" | "BSE") {
    setSyncing(true);
    try {
      const response = await api.post<SyncResult>(`/admin/instruments/sync/${exchange.toLowerCase()}`);
      message.success(
        `${exchange} 股票库同步完成：${response.data.totalRows} 只，新增 ${response.data.created}，更新 ${response.data.updated}`,
      );
      await loadRecords(1, pageSize);
    } catch (requestError: unknown) {
      message.error(apiError(requestError, `${exchange} 股票库同步失败`));
    } finally {
      setSyncing(false);
    }
  }

  async function setStatus(record: InstrumentMasterRecord, isActive: boolean) {
    try {
      await api.patch(`/admin/instruments/${record.id}/status`, { isActive });
      message.success(`${record.symbol} 已${isActive ? "启用" : "停用"}`);
      await loadRecords(page, pageSize);
    } catch (requestError: unknown) {
      message.error(apiError(requestError, "股票状态更新失败"));
    }
  }

  async function bulkSetStatus(isActive: boolean) {
    const symbols = records
      .filter((record) => selectedRowKeys.includes(record.id))
      .map((record) => record.id);
    if (symbols.length === 0) return;

    try {
      const response = await api.patch<{ updated: number }>("/admin/instruments/bulk-status", {
        instrumentIds: symbols,
        isActive,
      });
      message.success(`已${isActive ? "启用" : "停用"} ${response.data.updated ?? symbols.length} 只股票`);
      await loadRecords(page, pageSize);
    } catch (requestError: unknown) {
      message.error(apiError(requestError, "批量状态更新失败"));
    }
  }

  const columns: ColumnsType<InstrumentMasterRecord> = [
    {
      title: "股票",
      fixed: "left",
      width: 210,
      render: (_, record) => (
        <Space>
          <span
            style={{
              width: 36,
              height: 36,
              borderRadius: 10,
              display: "inline-flex",
              alignItems: "center",
              justifyContent: "center",
              background: "#eef4ff",
              border: "1px solid #dbe7f7",
            }}
          >
            <StockOutlined style={{ color: "#2563eb" }} />
          </span>
          <Space orientation="vertical" size={0}>
            <Text strong>{record.symbol}</Text>
            <Text type="secondary">{record.exchange}</Text>
          </Space>
        </Space>
      ),
    },
    {
      title: "公司名称",
      dataIndex: "name",
      width: 280,
      ellipsis: true,
    },
    {
      title: "ISIN",
      dataIndex: "isin",
      width: 170,
      render: (value) => value || "-",
    },
    {
      title: "分类",
      dataIndex: "category",
      width: 110,
      render: (value) => <Tag>{value || "EQUITY"}</Tag>,
    },
    {
      title: "每手",
      dataIndex: "lotSize",
      width: 90,
      align: "right",
    },
    {
      title: "最新价",
      width: 130,
      align: "right",
      render: (_, record) => formatPrice(record.quote?.lastPrice),
    },
    {
      title: "行情时间",
      width: 180,
      render: (_, record) => formatDate(record.quote?.asOf),
    },
    {
      title: "App 状态",
      dataIndex: "isActive",
      width: 130,
      render: (value: boolean, record) => (
        <Switch
          checked={value}
          checkedChildren="启用"
          unCheckedChildren="停用"
          onChange={(checked) => void setStatus(record, checked)}
        />
      ),
    },
    {
      title: "资料更新",
      dataIndex: "updatedAt",
      width: 180,
      render: formatDate,
    },
  ];

  function handleTableChange(pagination: TablePaginationConfig) {
    const nextPage = pagination.current ?? 1;
    const nextPageSize = pagination.pageSize ?? pageSize;
    void loadRecords(nextPage, nextPageSize);
  }

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>股票资料库 · NSE / BSE</Title>
          <Paragraph type="secondary">
            NSE 与 BSE 独立统计、独立同步、独立启用。新上市股票自动入库，默认停用；启用后进入行情轮询并展示在客户 App。
          </Paragraph>
        </div>

        {error && <Alert type="error" showIcon title={error} />}

        <Tabs activeKey={exchange} onChange={(key) => { requestVersion.current++; setRecords([]); setStatistics(undefined); setSelectedRowKeys([]); setSearch(""); setActive(undefined); setPage(1); setExchange(key as "NSE" | "BSE"); }} items={[{ key: "NSE", label: "NSE 股票库" }, { key: "BSE", label: "BSE 股票库" }]} />
        <Alert type="info" showIcon title={exchange === "NSE" ? "自动同步已开启 · 每天 06:00（印度时间）" : autoSync?.bse ? "自动同步已开启 · 每天 06:15（印度时间）" : "BSE 股票库已预留 · 接入数据源后自动开启每日同步"} />

        <Space wrap size="middle">
          <Card size="small"><Statistic title={`${exchange} 股票总数`} value={statistics?.total ?? "—"} suffix="只" /></Card>
          <Card size="small"><Statistic title="已启用总数" value={statistics?.enabled ?? "—"} suffix="只" /></Card>
          <Card size="small"><Statistic title="已有行情总数" value={statistics?.quoted ?? "—"} suffix="只" /></Card>
        </Space>

        <Card>
          <Space wrap style={{ width: "100%", justifyContent: "space-between" }}>
            <Space wrap>
              <Input
                allowClear
                prefix={<SearchOutlined />}
                placeholder="搜索代码、公司名称或 ISIN"
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                onPressEnter={() => void loadRecords(1, pageSize)}
                style={{ width: 330 }}
              />
              <Select
                allowClear
                placeholder="App 状态"
                value={active}
                onChange={(value) => setActive(value)}
                style={{ width: 140 }}
                options={[
                  { value: true, label: "已启用" },
                  { value: false, label: "已停用" },
                ]}
              />
              <Button type="primary" icon={<SearchOutlined />} onClick={() => void loadRecords(1, pageSize)}>
                查询
              </Button>
              <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void loadRecords(page, pageSize)}>
                刷新
              </Button>
            </Space>

            <Space>
            <Popconfirm title={`启用 ${exchange} 股票库中的全部股票？`} description={`仅启用 ${exchange} 全库股票，不受分页或搜索限制，不影响另一交易所。`} onConfirm={enableAll} okText="全部启用" cancelText="取消" disabled={enablingAll || syncing}>
              <Button icon={<CheckOutlined />} loading={enablingAll} disabled={syncing}>全部启用股票</Button>
            </Popconfirm>
            <Popconfirm
              title={`同步 ${exchange} 股票库？`}
              description="已有股票只更新基础资料，不会改变当前启用/停用状态。新发现股票默认停用。"
              okText="开始同步"
              cancelText="取消"
              onConfirm={() => void syncExchange(exchange)}
            >
              <Button type="primary" icon={<CloudSyncOutlined />} loading={syncing} disabled={exchange === "BSE" && !autoSync?.bse}>
                立即同步 {exchange}
              </Button>
            </Popconfirm>
            </Space>
          </Space>

          {selectedRowKeys.length > 0 && (
            <Alert
              type="info"
              showIcon
              style={{ marginTop: 16 }}
              title={`已选择 ${selectedRowKeys.length} 只股票`}
              action={
                <Space>
                  <Button size="small" type="primary" icon={<CheckOutlined />} onClick={() => void bulkSetStatus(true)}>
                    批量启用
                  </Button>
                  <Button size="small" danger icon={<CloseOutlined />} onClick={() => void bulkSetStatus(false)}>
                    批量停用
                  </Button>
                </Space>
              }
            />
          )}

          <Table<InstrumentMasterRecord>
            rowKey="id"
            columns={columns}
            dataSource={records}
            loading={loading}
            rowSelection={{
              selectedRowKeys,
              onChange: setSelectedRowKeys,
            }}
            scroll={{ x: 1450 }}
            style={{ marginTop: 16 }}
            pagination={{
              current: page,
              pageSize,
              total,
              showSizeChanger: true,
              pageSizeOptions: [20, 50, 100, 200],
              showTotal: (count) => `共 ${count} 只股票`,
            }}
            onChange={handleTableChange}
          />
        </Card>
      </Space>
    </AdminShell>
  );
}
