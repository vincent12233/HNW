"use client";

import { DownloadOutlined, ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Button, Input, Select, Space, Table, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsMoney from "@/components/OpsMoney";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import OpsToolbar from "@/components/OpsToolbar";
import { api, getApiErrorMessage } from "@/lib/api";
import { filterLoadedRows, maskOpsPhone } from "@/lib/ops-directory";
import { formatInr, formatOpsDateTime, OPS_TABLE_PAGINATION } from "@/lib/ops-format";
import { TRADING_COPY } from "@/lib/ops-trading";

const { Text } = Typography;

type Customer = {
  id: string;
  customerNo?: string | null;
  fullName?: string | null;
  phone?: string | null;
};

type Pair = {
  id: string;
  status: "OPEN" | "CLOSED";
  quantity: number;
  customer: Customer;
  accountNumber: string;
  instrument: { symbol: string; name: string; exchange: string };
  buyExecutionId: string;
  buyTime: string;
  buyPrice: number;
  buyFee: number;
  sellExecutionId?: string | null;
  sellTime?: string | null;
  sellPrice?: number | null;
  sellFee?: number | null;
  holdingSeconds?: number | null;
  realizedPnl?: number | null;
};

type Language = "zh" | "en";

const copy = {
  zh: {
    search: "搜索客户、账号、股票或成交编号",
    customer: "选择客户",
    empty: "没有可导出的记录",
    done: "英文交易记录已导出",
    choose: "请先选择一位客户",
    load: "交易记录加载失败",
    open: "持仓中",
    closed: "已卖出",
  },
  en: {
    search: "Search customer, account, symbol or execution ID",
    customer: "Select customer",
    empty: "No records to export",
    done: "English trade records exported",
    choose: "Select one customer first",
    load: "Failed to load trade records",
    open: "Open",
    closed: "Closed",
  },
};

function holdingLabel(seconds?: number | null) {
  if (seconds == null) return "—";
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  return `${days}d ${hours}h ${minutes}m`;
}

function csvCell(value: unknown) {
  const raw = String(value ?? "");
  const safe = /^[=+\-@\t\r]/.test(raw) ? `'${raw}` : raw;
  return `"${safe.split('"').join('""')}"`;
}

export default function BusinessTradesPage() {
  const [lang, setLang] = useState<Language>("zh");
  const [rows, setRows] = useState<Pair[]>([]);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [customerId, setCustomerId] = useState<string>();
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const t = copy[lang];
  const loadErrorRef = useRef(t.load);
  const customerIdRef = useRef(customerId);

  useEffect(() => {
    loadErrorRef.current = t.load;
    customerIdRef.current = customerId;
  });

  useEffect(() => {
    const sync = (event?: Event) =>
      setLang(((event as CustomEvent)?.detail || localStorage.getItem("businessLanguage")) === "en" ? "en" : "zh");
    sync();
    window.addEventListener("business-language-change", sync);
    api.get<Customer[]>("/business/my-customers").then((response) => {
      setCustomers(Array.isArray(response.data) ? response.data : []);
    });
    return () => window.removeEventListener("business-language-change", sync);
  }, []);

  const load = useCallback(async (id = customerIdRef.current) => {
    setLoading(true);
    setError("");
    try {
      const response = await api.get<{ data: Pair[] }>("/business/my-trade-pairs", {
        params: { customerId: id },
      });
      setRows(response.data.data || []);
    } catch (requestError: unknown) {
      setRows([]);
      setError(getApiErrorMessage(requestError, loadErrorRef.current));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const visible = useMemo(
    () =>
      filterLoadedRows(rows, search, (row) => [
        row.customer.fullName,
        row.customer.customerNo,
        maskOpsPhone(row.customer.phone, ""),
        row.accountNumber,
        row.instrument.symbol,
        row.instrument.name,
        row.buyExecutionId,
        row.sellExecutionId,
      ]),
    [rows, search],
  );

  function exportCsv(one: boolean) {
    if (one && !customerId) {
      message.warning(t.choose);
      return;
    }
    if (!visible.length) {
      message.info(t.empty);
      return;
    }
    const head = [
      "Customer No.",
      "Customer Name",
      "Masked Phone",
      "Trading Account",
      "Symbol",
      "Instrument Name",
      "Exchange",
      "Status",
      "Matched Quantity",
      "Buy Execution ID",
      "Buy Time (IST)",
      "Buy Price (INR)",
      "Buy Fee (INR)",
      "Sell Execution ID",
      "Sell Time (IST)",
      "Sell Price (INR)",
      "Sell Fee (INR)",
      "Holding Period",
      "Realized P&L (INR)",
      "Matching Method",
    ];
    const date = (value?: string | null) =>
      value ? new Date(value).toLocaleString("en-IN", { timeZone: "Asia/Kolkata" }) : "";
    const lines = [
      head,
      ...visible.map((row) => [
        row.customer.customerNo || "",
        row.customer.fullName || "",
        maskOpsPhone(row.customer.phone, ""),
        row.accountNumber,
        row.instrument.symbol,
        row.instrument.name,
        row.instrument.exchange,
        row.status === "CLOSED" ? "Closed" : "Open",
        row.quantity,
        row.buyExecutionId,
        date(row.buyTime),
        row.buyPrice,
        row.buyFee,
        row.sellExecutionId || "",
        date(row.sellTime),
        row.sellPrice ?? "",
        row.sellFee ?? "",
        holdingLabel(row.holdingSeconds),
        row.realizedPnl ?? "",
        "FIFO",
      ]),
    ].map((row) => row.map(csvCell).join(","));
    const blob = new Blob(["\ufeff" + lines.join("\r\n")], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `${one ? "customer" : "matched"}-trade-records-${new Date().toISOString().slice(0, 10)}.csv`;
    anchor.click();
    URL.revokeObjectURL(url);
    message.success(t.done);
  }

  const columns: ColumnsType<Pair> = [
    {
      title: lang === "zh" ? "客户" : "Customer",
      fixed: "left",
      width: 200,
      render: (_, row) => (
        <Space orientation="vertical" size={0}>
          <span className="ops-wrap-text">{row.customer.fullName || "—"}</span>
          <Text type="secondary">{row.customer.customerNo || "—"}</Text>
        </Space>
      ),
    },
    {
      title: lang === "zh" ? "交易账号" : "Account",
      dataIndex: "accountNumber",
      width: 150,
      render: (value: string) => <span className="ops-id">{value}</span>,
    },
    {
      title: lang === "zh" ? "股票" : "Instrument",
      width: 140,
      render: (_, row) => (
        <>
          <Text strong>{row.instrument.symbol}</Text>
          <br />
          <Text type="secondary">{row.instrument.exchange}</Text>
        </>
      ),
    },
    {
      title: lang === "zh" ? "状态" : "Status",
      width: 110,
      render: (_, row) => (
        <OpsStatusTag code={row.status} label={row.status === "CLOSED" ? t.closed : t.open} />
      ),
    },
    { title: lang === "zh" ? "配对数量" : "Qty", dataIndex: "quantity", align: "right", width: 100 },
    {
      title: lang === "zh" ? "买入时间" : "Buy Time",
      dataIndex: "buyTime",
      width: 170,
      render: (value: string) => formatOpsDateTime(value),
    },
    {
      title: lang === "zh" ? "买入价" : "Buy Price",
      dataIndex: "buyPrice",
      align: "right",
      width: 120,
      render: (value: number) => <OpsMoney value={value} />,
    },
    {
      title: lang === "zh" ? "买入费用" : "Buy Fee",
      dataIndex: "buyFee",
      align: "right",
      width: 110,
      render: (value: number) => <OpsMoney value={value} />,
    },
    {
      title: lang === "zh" ? "卖出时间" : "Sell Time",
      dataIndex: "sellTime",
      width: 170,
      render: (value?: string | null) => formatOpsDateTime(value),
    },
    {
      title: lang === "zh" ? "卖出价" : "Sell Price",
      dataIndex: "sellPrice",
      align: "right",
      width: 120,
      render: (value?: number | null) => <OpsMoney value={value} />,
    },
    {
      title: lang === "zh" ? "卖出费用" : "Sell Fee",
      dataIndex: "sellFee",
      align: "right",
      width: 110,
      render: (value?: number | null) => <OpsMoney value={value} />,
    },
    {
      title: lang === "zh" ? "持有时长" : "Holding",
      dataIndex: "holdingSeconds",
      width: 120,
      render: (value?: number | null) => holdingLabel(value),
    },
    {
      title: lang === "zh" ? "已实现盈亏" : "P&L",
      dataIndex: "realizedPnl",
      align: "right",
      width: 140,
      render: (value?: number | null) => (
        <Text type={value == null ? "secondary" : value >= 0 ? "success" : "danger"}>{formatInr(value)}</Text>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title={lang === "zh" ? TRADING_COPY.pairsTitle : "Matched Customer Trades"}
          crumbs={[{ title: lang === "zh" ? "交易业务" : "Trading" }, { title: lang === "zh" ? TRADING_COPY.pairsTitle : "Matched trades" }]}
          description={lang === "zh" ? TRADING_COPY.pairsDesc : TRADING_COPY.pairsDesc}
        />
        {error ? <OpsErrorState title={error} onRetry={() => void load()} /> : null}
        <OpsToolbar
          extra={
            <Space wrap>
              <Button type="primary" icon={<SearchOutlined />} loading={loading} onClick={() => void load()} aria-label="查询配对成交">
                {lang === "zh" ? "查询" : "Search"}
              </Button>
              <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void load()} aria-label="刷新配对成交">
                {lang === "zh" ? "刷新" : "Refresh"}
              </Button>
              <Button icon={<DownloadOutlined />} onClick={() => exportCsv(false)} aria-label="导出当前配对结果">
                {lang === "zh" ? "导出当前结果" : "Export"}
              </Button>
              <Button
                icon={<DownloadOutlined />}
                disabled={!customerId}
                onClick={() => exportCsv(true)}
                aria-label="导出所选客户配对"
              >
                {lang === "zh" ? "导出该客户" : "Export customer"}
              </Button>
            </Space>
          }
        >
          <Input
            allowClear
            prefix={<SearchOutlined aria-hidden />}
            placeholder={t.search}
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            aria-label={t.search}
            style={{ width: 340, maxWidth: "100%" }}
          />
          <Select
            allowClear
            showSearch
            optionFilterProp="label"
            placeholder={t.customer}
            value={customerId}
            onChange={(value) => {
              setCustomerId(value);
              void load(value);
            }}
            style={{ width: 260 }}
            aria-label={t.customer}
            options={customers.map((customer) => ({
              value: customer.id,
              label: `${customer.fullName || "—"} · ${customer.customerNo || maskOpsPhone(customer.phone)}`,
            }))}
          />
        </OpsToolbar>
        <Text type="secondary">{TRADING_COPY.loadedFilter}</Text>
        <Table<Pair>
          rowKey="id"
          className="ops-directory-table"
          columns={columns}
          dataSource={visible}
          loading={loading}
          scroll={{ x: 1900 }}
          pagination={OPS_TABLE_PAGINATION}
          locale={{
            emptyText: (
              <OpsEmpty
                description={loading ? "正在加载配对成交" : "当前没有配对成交。"}
                onRetry={loading ? undefined : () => void load()}
              />
            ),
          }}
        />
      </Space>
    </AdminShell>
  );
}
