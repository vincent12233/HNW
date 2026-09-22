"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import {
  Alert,
  Button,
  Input,
  InputNumber,
  Select,
  Space,
  Switch,
  Table,
  Typography,
  message,
} from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import OpsToolbar from "@/components/OpsToolbar";
import { api, getApiErrorMessage } from "@/lib/api";

const { Text } = Typography;

type InstrumentRow = {
  id: string;
  symbol: string;
  name: string;
  exchange: string;
  isActive: boolean;
  featuredHome: boolean;
  featuredMarkets: boolean;
  displayOrder: number;
};

type ListResponse = {
  page: number;
  pageSize: number;
  total: number;
  data: InstrumentRow[];
};

export default function FeaturedInstrumentsPage() {
  const [rows, setRows] = useState<InstrumentRow[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [search, setSearch] = useState("");
  const [exchange, setExchange] = useState<string | undefined>();
  const [featuredHome, setFeaturedHome] = useState<boolean | undefined>();
  const [featuredMarkets, setFeaturedMarkets] = useState<boolean | undefined>();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [savingId, setSavingId] = useState<string | null>(null);

  const loadGeneration = useRef(0);
  const saveLock = useRef(false);

  async function load(nextPage = page, nextPageSize = pageSize) {
    const generation = ++loadGeneration.current;
    setLoading(true);
    setError("");
    try {
      const { data } = await api.get<ListResponse>("/admin/market/instruments", {
        params: {
          search: search.trim() || undefined,
          exchange,
          featuredHome,
          featuredMarkets,
          page: nextPage,
          pageSize: nextPageSize,
        },
      });
      if (generation !== loadGeneration.current) return;
      setRows(Array.isArray(data?.data) ? data.data : []);
      setTotal(data?.total ?? 0);
      setPage(data?.page ?? nextPage);
      setPageSize(data?.pageSize ?? nextPageSize);
    } catch (e: unknown) {
      if (generation === loadGeneration.current) {
        setError(getApiErrorMessage(e, "精选标的加载失败"));
      }
    } finally {
      if (generation === loadGeneration.current) setLoading(false);
    }
  }

  useEffect(() => {
    void load(1, pageSize);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function patchPlacement(
    row: InstrumentRow,
    patch: Partial<Pick<InstrumentRow, "featuredHome" | "featuredMarkets" | "displayOrder">>,
  ) {
    if (saveLock.current) return;
    saveLock.current = true;
    setSavingId(row.id);
    try {
      await api.patch(`/admin/market/instruments/${row.id}/placement`, patch);
      message.success("已更新精选配置");
      await load(page, pageSize);
    } catch (e: unknown) {
      message.error(getApiErrorMessage(e, "更新失败"));
    } finally {
      saveLock.current = false;
      setSavingId(null);
    }
  }

  function saveDisplayOrder(row: InstrumentRow, raw: string) {
    if (!raw.trim()) {
      message.warning("排序不能为空，请输入 0 到 1000000 的整数。");
      return;
    }
    const next = Number(raw);
    if (!Number.isInteger(next) || next < 0 || next > 1_000_000) {
      message.warning("排序必须是 0 到 1000000 的整数。");
      return;
    }
    if (next !== row.displayOrder) void patchPlacement(row, { displayOrder: next });
  }

  const columns: ColumnsType<InstrumentRow> = [
    {
      title: "标的",
      render: (_, row) => (
        <Space orientation="vertical" size={0}>
          <Text strong>
            {row.symbol} · {row.exchange}
          </Text>
          <Text type="secondary">{row.name}</Text>
        </Space>
      ),
    },
    {
      title: "上架",
      width: 90,
      render: (_, row) => <OpsStatusTag code={row.isActive ? "ACTIVE" : "INACTIVE"} />,
    },
    {
      title: "Home Featured",
      width: 130,
      render: (_, row) => (
        <Switch
          aria-label={`${row.symbol} 首页精选`}
          disabled={savingId !== null}
          checked={row.featuredHome}
          loading={savingId === row.id}
          onChange={(checked) => void patchPlacement(row, { featuredHome: checked })}
          checkedChildren="On"
          unCheckedChildren="Off"
        />
      ),
    },
    {
      title: "Markets Featured",
      width: 150,
      render: (_, row) => (
        <Switch
          aria-label={`${row.symbol} 行情页精选`}
          disabled={savingId !== null}
          checked={row.featuredMarkets}
          loading={savingId === row.id}
          onChange={(checked) => void patchPlacement(row, { featuredMarkets: checked })}
          checkedChildren="On"
          unCheckedChildren="Off"
        />
      ),
    },
    {
      title: "Display Order",
      width: 140,
      render: (_, row) => (
        <InputNumber
          min={0}
          max={1_000_000}
          changeOnBlur={false}
          value={row.displayOrder}
          aria-label={`${row.symbol} 展示排序`}
          disabled={savingId !== null}
          onBlur={(e) => saveDisplayOrder(row, e.target.value)}
          onPressEnter={(e) => saveDisplayOrder(row, (e.target as HTMLInputElement).value)}
          style={{ width: 100 }}
        />
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          eyebrow="APP MANAGEMENT"
          title="精选标的"
          description="复用 Instrument 主数据：仅切换 Home/Markets Featured 与 Display Order。不复制股票、不改报价、不改交易规则。"
          extra={
            <Button
              icon={<ReloadOutlined />}
              loading={loading}
              onClick={() => void load(page, pageSize)}
              aria-label="刷新精选标的"
            >
              刷新
            </Button>
          }
        />

        <Alert
          type="info"
          showIcon
          title="仅修改展示位置"
          description="本页不创建股票、不同步行情、不修改 isActive/tradability。股票库与行情仍走既有市场/资料库流程。"
        />

        {error ? <OpsErrorState title={error} onRetry={() => void load(1, pageSize)} /> : null}

        <OpsToolbar
          extra={
            <Button
              type="primary"
              icon={<SearchOutlined />}
              loading={loading}
              onClick={() => void load(1, pageSize)}
              aria-label="查询精选标的"
            >
              查询
            </Button>
          }
        >
          <Input
            allowClear
            prefix={<SearchOutlined aria-hidden />}
            placeholder="搜索 symbol / 公司 / ISIN"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onPressEnter={() => void load(1, pageSize)}
            style={{ width: 280, maxWidth: "100%" }}
            aria-label="搜索标的"
          />
          <Select
            allowClear
            placeholder="交易所"
            style={{ width: 120 }}
            value={exchange}
            onChange={(v) => setExchange(v)}
            options={[
              { value: "NSE", label: "NSE" },
              { value: "BSE", label: "BSE" },
            ]}
          />
          <Select
            allowClear
            placeholder="Home Featured"
            style={{ width: 160 }}
            value={featuredHome === undefined ? undefined : featuredHome ? "yes" : "no"}
            onChange={(v) => setFeaturedHome(v === undefined ? undefined : v === "yes")}
            options={[
              { value: "yes", label: "Home = On" },
              { value: "no", label: "Home = Off" },
            ]}
          />
          <Select
            allowClear
            placeholder="Markets Featured"
            style={{ width: 170 }}
            value={featuredMarkets === undefined ? undefined : featuredMarkets ? "yes" : "no"}
            onChange={(v) => setFeaturedMarkets(v === undefined ? undefined : v === "yes")}
            options={[
              { value: "yes", label: "Markets = On" },
              { value: "no", label: "Markets = Off" },
            ]}
          />
        </OpsToolbar>

        <Table
          rowKey="id"
          className="ops-directory-table"
          loading={loading}
          columns={columns}
          dataSource={rows}
          pagination={{
            current: page,
            pageSize,
            total,
            showSizeChanger: true,
            pageSizeOptions: [20, 50, 100],
            showTotal: (t) => `共 ${t} 条`,
            onChange: (p, ps) => void load(p, ps),
          }}
          scroll={{ x: 900 }}
          locale={{ emptyText: <OpsEmpty description={loading ? "正在加载精选标的" : "当前没有符合条件的标的。"} onRetry={loading ? undefined : () => void load(1, pageSize)} /> }}
        />
      </Space>
    </AdminShell>
  );
}
