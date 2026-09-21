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
  Typography,
  message,
} from "antd";
import type { ColumnsType, TablePaginationConfig } from "antd/es/table";
import { useCallback, useEffect, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsDrawer from "@/components/OpsDrawer";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsMoney from "@/components/OpsMoney";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import OpsToolbar from "@/components/OpsToolbar";
import { api } from "@/lib/api";
import { formatOpsDateTime, OPS_TABLE_PAGINATION } from "@/lib/ops-format";
import { PRODUCT_COPY } from "@/lib/ops-product";

const { Text } = Typography;

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
  if (value === null || value === undefined || Number(value) <= 0) return "—";
  return <OpsMoney value={value} />;
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
  const [detail, setDetail] = useState<InstrumentMasterRecord | null>(null);
  const [selectedRowKeys, setSelectedRowKeys] = useState<React.Key[]>([]);
  const filtersRef = useRef({ search, active, exchange, page, pageSize });
  useEffect(() => {
    filtersRef.current = { search, active, exchange, page, pageSize };
  });

  const loadRecords = useCallback(async (nextPage?: number, nextPageSize?: number) => {
    const {
      search: nextSearch,
      active: nextActive,
      exchange: nextExchange,
      page: currentPage,
      pageSize: currentPageSize,
    } = filtersRef.current;
    const pageToLoad = nextPage ?? currentPage;
    const pageSizeToLoad = nextPageSize ?? currentPageSize;
    const version = ++requestVersion.current;
    setLoading(true);
    setError("");
    try {
      const response = await api.get<InstrumentMasterResponse>("/admin/instruments", {
        params: {
          search: nextSearch.trim() || undefined,
          active: nextActive,
          exchange: nextExchange,
          page: pageToLoad,
          pageSize: pageSizeToLoad,
        },
      });
      if (version !== requestVersion.current) return;
      setStatistics(response.data.statistics);
      setAutoSync(response.data.autoSync);
      setRecords(Array.isArray(response.data.data) ? response.data.data : []);
      setTotal(Number(response.data.total ?? 0));
      setPage(Number(response.data.page ?? pageToLoad));
      setPageSize(Number(response.data.pageSize ?? pageSizeToLoad));
      setSelectedRowKeys([]);
    } catch (requestError: unknown) {
      if (version !== requestVersion.current) return;
      setError(apiError(requestError, "股票库加载失败"));
    } finally {
      if (version === requestVersion.current) setLoading(false);
    }
  }, []);

  useEffect(() => {
    const versionRef = requestVersion;
    const timer = window.setTimeout(() => {
      void loadRecords(1, 50);
    }, 0);
    return () => {
      window.clearTimeout(timer);
      // Invalidate in-flight loads from this effect instance on exchange switch/unmount.
      versionRef.current += 1;
    };
    // Initial server load only; filters are submitted explicitly.
  }, [exchange, loadRecords]);

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
            <Text type="secondary" className="ops-wrap-text">{record.name}</Text>
          </Space>
        </Space>
      ),
    },
    {
      title: "公司名称",
      dataIndex: "name",
      width: 280,
      render: (value) => <span className="ops-wrap-text">{value}</span>,
    },
    {
      title: "ISIN",
      dataIndex: "isin",
      width: 170,
      render: (value) => value || "—",
    },
    {
      title: "分类",
      dataIndex: "category",
      width: 110,
      render: (value) => <OpsStatusTag code={value || "EQUITY"} label={value || "EQUITY"} />,
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
      render: (_, record) => formatOpsDateTime(record.quote?.asOf),
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
          aria-label={`${record.symbol} ${value ? "已启用" : "已停用"}`}
          onChange={(checked) => void setStatus(record, checked)}
        />
      ),
    },
    {
      title: "资料更新",
      dataIndex: "updatedAt",
      width: 180,
      render: (value: string) => formatOpsDateTime(value),
    },
  ];

  function handleTableChange(pagination: TablePaginationConfig) {
    const nextPage = pagination.current ?? 1;
    const nextPageSize = pagination.pageSize ?? pageSize;
    void loadRecords(nextPage, nextPageSize);
  }

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title={PRODUCT_COPY.instrumentsTitle}
          crumbs={[{ title: "产品" }, { title: PRODUCT_COPY.instrumentsTitle }]}
          description={`NSE 与 BSE 独立统计、独立同步、独立启用。新上市股票自动入库，默认停用；启用后进入行情轮询并展示在客户 App。${PRODUCT_COPY.catalogNotTraded} ${PRODUCT_COPY.noVip}`}
        />

        {error ? <OpsErrorState title={error} onRetry={() => void loadRecords(page, pageSize)} /> : null}

        <Tabs activeKey={exchange} onChange={(key) => { requestVersion.current++; setRecords([]); setStatistics(undefined); setSelectedRowKeys([]); setSearch(""); setActive(undefined); setPage(1); setExchange(key as "NSE" | "BSE"); }} items={[{ key: "NSE", label: "NSE 股票库" }, { key: "BSE", label: "BSE 股票库" }]} />
        <Alert type="info" showIcon title={exchange === "NSE" ? "自动同步已开启 · 每天 06:00（印度时间）" : autoSync?.bse ? "自动同步已开启 · 每天 06:15（印度时间）" : "BSE 股票库已预留 · 接入数据源后自动开启每日同步"} />

        <Space wrap size="middle">
          <Card size="small"><Statistic title={`${exchange} 股票总数`} value={statistics?.total ?? "—"} suffix="只" /></Card>
          <Card size="small"><Statistic title="已启用总数" value={statistics?.enabled ?? "—"} suffix="只" /></Card>
          <Card size="small"><Statistic title="已有行情总数" value={statistics?.quoted ?? "—"} suffix="只" /></Card>
        </Space>

        <OpsToolbar
          extra={
            <Space wrap>
            <Popconfirm title={`启用 ${exchange} 股票库中的全部股票？`} description={`仅启用 ${exchange} 全库股票，不受分页或搜索限制，不影响另一交易所。`} onConfirm={enableAll} okText="全部启用" cancelText="返回" disabled={enablingAll || syncing}>
              <Button icon={<CheckOutlined />} loading={enablingAll} disabled={syncing} aria-label={`全部启用 ${exchange} 股票`}>全部启用股票</Button>
            </Popconfirm>
            <Popconfirm
              title={`同步 ${exchange} 股票库？`}
              description="已有股票只更新基础资料，不会改变当前启用/停用状态。新发现股票默认停用。同步不是交易。"
              okText="开始同步"
              cancelText="返回"
              onConfirm={() => void syncExchange(exchange)}
            >
              <Button type="primary" icon={<CloudSyncOutlined />} loading={syncing} disabled={exchange === "BSE" && !autoSync?.bse} aria-label={`立即同步 ${exchange}`}>
                立即同步 {exchange}
              </Button>
            </Popconfirm>
            </Space>
          }
        >
              <Input
                allowClear
                prefix={<SearchOutlined aria-hidden />}
                placeholder="搜索代码、公司名称或 ISIN"
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                onPressEnter={() => void loadRecords(1, pageSize)}
                aria-label="搜索股票资料库"
                style={{ width: 330, maxWidth: "100%" }}
              />
              <Select
                allowClear
                placeholder="App 状态"
                value={active}
                onChange={(value) => setActive(value)}
                aria-label="按启用状态筛选"
                style={{ width: 140 }}
                options={[
                  { value: true, label: "已启用" },
                  { value: false, label: "已停用" },
                ]}
              />
              <Button type="primary" icon={<SearchOutlined />} onClick={() => void loadRecords(1, pageSize)} aria-label="查询股票">
                查询
              </Button>
              <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void loadRecords(page, pageSize)} aria-label="刷新股票列表">
                刷新
              </Button>
        </OpsToolbar>

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
            className="ops-directory-table"
            columns={columns}
            dataSource={records}
            loading={loading}
            onRow={(record) => ({
              onClick: () => setDetail(record),
            })}
            rowSelection={{
              selectedRowKeys,
              onChange: setSelectedRowKeys,
            }}
            scroll={{ x: 1450 }}
            style={{ marginTop: 16 }}
            locale={{ emptyText: <OpsEmpty description={error ? "股票库未能加载，请刷新重试" : "当前没有股票资料。"} onRetry={() => void loadRecords(page, pageSize)} /> }}
            pagination={{
              current: page,
              pageSize,
              total,
              showSizeChanger: true,
              pageSizeOptions: OPS_TABLE_PAGINATION.pageSizeOptions,
              showTotal: (count) => `共 ${count} 只股票`,
            }}
            onChange={handleTableChange}
          />
        <OpsDrawer
          title={detail ? `${detail.exchange}:${detail.symbol}` : "股票详情"}
          open={!!detail}
          onClose={() => setDetail(null)}
        >
          {detail ? (
            <Space orientation="vertical" size="middle">
              <Text className="ops-wrap-text">{detail.name}</Text>
              <Text>ISIN {detail.isin || "—"}</Text>
              <Text>分类 {detail.category || "EQUITY"}</Text>
              <Text>每手 {detail.lotSize}</Text>
              <Text>最新价 {detail.quote?.lastPrice != null && Number(detail.quote.lastPrice) > 0 ? undefined : "—"}{detail.quote?.lastPrice != null && Number(detail.quote.lastPrice) > 0 ? <OpsMoney value={detail.quote.lastPrice} /> : null}</Text>
              <OpsStatusTag code={detail.isActive ? "ACTIVE" : "INACTIVE"} label={detail.isActive ? "已启用" : "已停用"} />
              <Text type="secondary">{PRODUCT_COPY.catalogNotTraded}</Text>
            </Space>
          ) : null}
        </OpsDrawer>
      </Space>
    </AdminShell>
  );
}
