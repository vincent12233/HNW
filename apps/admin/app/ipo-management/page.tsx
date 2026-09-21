"use client";

import { EditOutlined, PlusOutlined, ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import {
  Button,
  DatePicker,
  Form,
  Input,
  InputNumber,
  Select,
  Space,
  Table,
  Typography,
  message,
} from "antd";
import dayjs from "dayjs";
import { useEffect, useMemo, useState } from "react";
import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsModal from "@/components/OpsModal";
import OpsMoney from "@/components/OpsMoney";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import OpsToolbar from "@/components/OpsToolbar";
import { api, getApiErrorMessage } from "@/lib/api";
import { filterLoadedRows } from "@/lib/ops-directory";
import { formatOpsDateTime, OPS_TABLE_PAGINATION } from "@/lib/ops-format";
import { PRODUCT_COPY, ipoCatalogStatusLabel } from "@/lib/ops-product";

const { Text } = Typography;

type Instrument = {
  id: string;
  symbol: string;
  exchange: "NSE" | "BSE";
  name: string;
};

type Ipo = {
  id: string;
  symbol: string;
  companyName: string;
  exchange: string;
  issuePrice: string;
  marketPrice?: string;
  lotSize: number;
  totalShares: number;
  availableShares: number;
  reservedDraftShares?: number;
  remainingShares?: number;
  openDate: string;
  closeDate: string;
  status:
    | "DRAFT"
    | "PUBLISHED"
    | "OPEN"
    | "CLOSED"
    | "LISTED"
    | "ALLOTMENT_DONE";
  applicationCount: number;
};

function canEditPricing(record: Ipo) {
  if (
    record.status === "CLOSED" ||
    record.status === "LISTED" ||
    record.status === "ALLOTMENT_DONE"
  ) {
    return false;
  }
  return record.status === "DRAFT" || record.applicationCount === 0;
}

export default function IpoManagementPage() {
  const [items, setItems] = useState<Ipo[]>([]);
  const [instruments, setInstruments] = useState<Instrument[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [keyword, setKeyword] = useState("");
  const [open, setOpen] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const [editing, setEditing] = useState<Ipo | null>(null);
  const [confirming, setConfirming] = useState<{ record: Ipo; status: Ipo["status"] } | null>(null);
  const [savingStatus, setSavingStatus] = useState(false);
  const [form] = Form.useForm();
  const [editForm] = Form.useForm();

  async function load() {
    setLoading(true);
    setError("");
    try {
      const [ipoResponse, instrumentResponse] = await Promise.all([
        api.get<{ data: Ipo[] }>("/admin/ipo"),
        api.get<{ data: Instrument[] }>(
          "/admin/market/instruments?pageSize=100",
        ),
      ]);
      setItems(ipoResponse.data.data ?? []);
      setInstruments(instrumentResponse.data.data ?? []);
    } catch (requestError: unknown) {
      setError(getApiErrorMessage(requestError, "IPO 列表加载失败"));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, []);

  async function create() {
    const values = await form.validateFields();
    const instrument = instruments.find(
      (item) => item.id === values.instrumentId,
    )!;
    try {
      await api.post("/admin/ipo", {
        symbol: instrument.symbol,
        companyName: values.companyName,
        exchange: instrument.exchange,
        instrumentId: instrument.id,
        issuePrice: Number(values.issuePrice).toFixed(2),
        lotSize: Number(values.lotSize),
        totalShares: Number(values.totalShares),
        openDate: values.period[0].toISOString(),
        closeDate: values.period[1].toISOString(),
      });
      message.success(
        "IPO 已上架到 APP，认购期间客户可申请；上架不代表上市",
      );
      setOpen(false);
      form.resetFields();
      await load();
    } catch (error) {
      message.error(getApiErrorMessage(error, "创建 IPO 失败，请稍后重试"));
    }
  }

  function openEdit(record: Ipo) {
    setEditing(record);
    editForm.setFieldsValue({
      issuePrice: Number(record.issuePrice),
      period: [dayjs(record.openDate), dayjs(record.closeDate)],
    });
    setEditOpen(true);
  }

  async function saveEdit() {
    if (!editing) return;
    const values = await editForm.validateFields();
    try {
      await api.patch(`/admin/ipo/${editing.id}`, {
        issuePrice: Number(values.issuePrice).toFixed(2),
        openDate: values.period[0].toISOString(),
        closeDate: values.period[1].toISOString(),
      });
      message.success("已更新申购价与认购期间（结算仍按申购价）");
      setEditOpen(false);
      setEditing(null);
      editForm.resetFields();
      await load();
    } catch (error) {
      message.error(getApiErrorMessage(error, "保存失败，请稍后重试"));
    }
  }

  async function setStatus(record: Ipo, status: Ipo["status"]) {
    if (savingStatus) return;
    setSavingStatus(true);
    try {
      await api.patch(`/admin/ipo/${record.id}/status`, { status });
      message.success(
        status === "PUBLISHED"
          ? "IPO 已上架到 APP（不代表上市）"
          : status === "CLOSED"
            ? "IPO 已下架"
            : "状态已更新",
      );
      setConfirming(null);
      await load();
    } catch (error) {
      message.error(getApiErrorMessage(error, "状态更新失败，请稍后重试"));
    } finally {
      setSavingStatus(false);
    }
  }

  const filtered = useMemo(
    () =>
      filterLoadedRows(items, keyword, (item) => [
        item.symbol,
        item.companyName,
        item.exchange,
        item.status,
      ]),
    [items, keyword],
  );

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title={PRODUCT_COPY.ipoTitle}
          crumbs={[{ title: "产品" }, { title: PRODUCT_COPY.ipoTitle }]}
          description={`超级管理员只负责将产品上架到 APP。客户申请的审核、分配和公布由业务员后台处理；上架不代表 IPO 已上市。${PRODUCT_COPY.listedNotSettled} ${PRODUCT_COPY.noVip}`}
        />
        {error ? <OpsErrorState title={error} onRetry={load} /> : null}
        <OpsToolbar
          extra={
            <Space wrap>
              <Button icon={<ReloadOutlined />} onClick={load} loading={loading} aria-label="刷新 IPO 列表">刷新</Button>
              <Button type="primary" icon={<PlusOutlined />} onClick={() => setOpen(true)} aria-label="创建 IPO">创建 IPO</Button>
            </Space>
          }
        >
          <Input allowClear prefix={<SearchOutlined aria-hidden />} placeholder="搜索已加载的代码、公司或状态" value={keyword} onChange={(event) => setKeyword(event.target.value)} aria-label="搜索已加载的 IPO" style={{ width: 360, maxWidth: "100%" }} />
        </OpsToolbar>
        <Text type="secondary">{PRODUCT_COPY.loadedFilter}</Text>
          <Table<Ipo>
            rowKey="id"
            className="ops-directory-table"
            loading={loading}
            dataSource={filtered}
            scroll={{ x: 1280 }}
            pagination={OPS_TABLE_PAGINATION}
            locale={{ emptyText: <OpsEmpty description={loading ? "正在加载 IPO" : "当前没有 IPO 记录。"} onRetry={loading ? undefined : load} /> }}
            columns={[
              {
                title: "IPO",
                width: 220,
                render: (_, r) => (
                  <Space orientation="vertical" size={0}>
                    <Text strong>{r.symbol}</Text>
                    <Text type="secondary" className="ops-wrap-text">{r.companyName}</Text>
                  </Space>
                ),
              },
              { title: "申购价", dataIndex: "issuePrice", width: 110, align: "right", render: (v) => <OpsMoney value={v} /> },
              {
                title: "展示行情",
                dataIndex: "marketPrice",
                width: 110,
                align: "right",
                render: (v: string | undefined, r) => <OpsMoney value={v ?? r.issuePrice} />,
              },
              { title: "每手", dataIndex: "lotSize", width: 90 },
              { title: "发行总量", dataIndex: "totalShares", width: 100 },
              {
                title: "可用股数",
                width: 160,
                render: (_, r) => (
                  <Space orientation="vertical" size={0}>
                    <Text>
                      剩余可分配 {r.remainingShares ?? r.availableShares}
                    </Text>
                    <Text type="secondary" style={{ fontSize: 12 }}>
                      未公布草稿占用 {r.reservedDraftShares ?? 0} · 公布后库存{" "}
                      {r.availableShares}
                    </Text>
                  </Space>
                ),
              },
              { title: "申购数", dataIndex: "applicationCount", width: 90 },
              {
                title: "状态",
                dataIndex: "status",
                width: 180,
                render: (v: string) => (
                  <OpsStatusTag code={v === "OPEN" ? "OPEN_IPO" : v} label={ipoCatalogStatusLabel(v)} />
                ),
              },
              {
                title: "申购期间",
                width: 310,
                render: (_, r) =>
                  `${formatOpsDateTime(r.openDate)} — ${formatOpsDateTime(r.closeDate)}`,
              },
              {
                title: "操作",
                fixed: "right",
                width: 280,
                render: (_, r) => (
                  <Space wrap>
                    <Button
                      size="small"
                      icon={<EditOutlined />}
                      disabled={!canEditPricing(r)}
                      aria-label={`编辑 ${r.symbol} 申购价`}
                      onClick={() => openEdit(r)}
                    >
                      编辑申购价
                    </Button>
                    <Button
                      size="small"
                      type="primary"
                      disabled={
                        r.status === "PUBLISHED" ||
                        r.status === "OPEN" ||
                        r.status === "LISTED" ||
                        r.status === "ALLOTMENT_DONE"
                      }
                      aria-label={`上架 ${r.symbol}`}
                      onClick={() => setConfirming({ record: r, status: "PUBLISHED" })}
                    >
                      上架到 APP
                    </Button>
                    <Button
                      size="small"
                      danger
                      disabled={r.status !== "PUBLISHED" && r.status !== "OPEN"}
                      aria-label={`下架 ${r.symbol}`}
                      onClick={() => setConfirming({ record: r, status: "CLOSED" })}
                    >
                      下架
                    </Button>
                  </Space>
                ),
              },
            ]}
          />
        <OpsModal
          title="创建并上架到 APP"
          open={open}
          onCancel={() => setOpen(false)}
          onOk={create}
          okText="创建并上架到 APP"
          zIndex={2100}
        >
          <Form form={form} layout="vertical">
            <Form.Item
              name="instrumentId"
              label="关联股票"
              rules={[{ required: true }]}
            >
              <Select
                showSearch
                optionFilterProp="label"
                options={instruments.map((i) => ({
                  value: i.id,
                  label: `${i.exchange}:${i.symbol} · ${i.name}`,
                }))}
              />
            </Form.Item>
            <Form.Item
              name="companyName"
              label="公司名称"
              rules={[{ required: true }]}
            >
              <Input />
            </Form.Item>
            <Form.Item
              name="issuePrice"
              label="申购价（结算价）"
              rules={[{ required: true }]}
            >
              <InputNumber min={0.01} precision={2} style={{ width: "100%" }} />
            </Form.Item>
            <Form.Item
              name="lotSize"
              label="每手股数"
              rules={[{ required: true }]}
            >
              <InputNumber min={1} precision={0} style={{ width: "100%" }} />
            </Form.Item>
            <Form.Item
              name="totalShares"
              label="发行总股数"
              rules={[{ required: true }]}
            >
              <InputNumber min={1} precision={0} style={{ width: "100%" }} />
            </Form.Item>
            <Form.Item
              name="period"
              label="申购期间"
              rules={[{ required: true }]}
            >
              <DatePicker.RangePicker showTime style={{ width: "100%" }} />
            </Form.Item>
          </Form>
        </OpsModal>
        <OpsModal
          title={
            editing ? `编辑申购价 · ${editing.symbol}` : "编辑申购价"
          }
          open={editOpen}
          onCancel={() => {
            setEditOpen(false);
            setEditing(null);
            editForm.resetFields();
          }}
          onOk={saveEdit}
          okText="保存"
          zIndex={2100}
        >
          <Text type="secondary" style={{ display: "block", marginBottom: 12 }}>
            仅草稿或尚无申购时可修改。分配与入账始终按存储的申购价结算。
          </Text>
          <Form form={editForm} layout="vertical">
            <Form.Item
              name="issuePrice"
              label="申购价（结算价）"
              rules={[{ required: true }]}
            >
              <InputNumber min={0.01} precision={2} style={{ width: "100%" }} />
            </Form.Item>
            <Form.Item
              name="period"
              label="申购期间"
              rules={[{ required: true }]}
            >
              <DatePicker.RangePicker showTime style={{ width: "100%" }} />
            </Form.Item>
          </Form>
        </OpsModal>
        <OpsModal
          title={confirming?.status === "CLOSED" ? "确认下架 IPO" : "确认上架到 APP"}
          open={!!confirming}
          confirmLoading={savingStatus}
          onCancel={() => { if (!savingStatus) setConfirming(null); }}
          onOk={() => confirming && setStatus(confirming.record, confirming.status)}
          okText="提交到服务器"
          cancelText="返回"
          okButtonProps={{ danger: confirming?.status === "CLOSED" }}
          zIndex={2100}
        >
          {confirming ? (
            <Space orientation="vertical">
              <Text>{confirming.record.symbol} · {confirming.record.companyName} · 当前 {ipoCatalogStatusLabel(confirming.record.status)}</Text>
              <Text type="secondary">{confirming.status === "PUBLISHED" ? "上架不代表上市或已成交。" : "下架后客户无法继续认购。"} {PRODUCT_COPY.listedNotSettled}</Text>
            </Space>
          ) : null}
        </OpsModal>
      </Space>
    </AdminShell>
  );
}
