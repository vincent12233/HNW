"use client";

import { EditOutlined, PlusOutlined, ReloadOutlined } from "@ant-design/icons";
import {
  Button,
  Card,
  DatePicker,
  Form,
  Input,
  InputNumber,
  Modal,
  Select,
  Space,
  Table,
  Tag,
  Typography,
  message,
} from "antd";
import dayjs from "dayjs";
import { useEffect, useState } from "react";
import AdminShell from "@/components/AdminShell";
import { api, getApiErrorMessage } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;

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
  const [open, setOpen] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const [editing, setEditing] = useState<Ipo | null>(null);
  const [form] = Form.useForm();
  const [editForm] = Form.useForm();

  async function load() {
    setLoading(true);
    try {
      const [ipoResponse, instrumentResponse] = await Promise.all([
        api.get<{ data: Ipo[] }>("/admin/ipo"),
        api.get<{ data: Instrument[] }>(
          "/admin/market/instruments?pageSize=100",
        ),
      ]);
      setItems(ipoResponse.data.data ?? []);
      setInstruments(instrumentResponse.data.data ?? []);
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
    try {
      await api.patch(`/admin/ipo/${record.id}/status`, { status });
      message.success(
        status === "PUBLISHED"
          ? "IPO 已上架到 APP（不代表上市）"
          : status === "CLOSED"
            ? "IPO 已下架"
            : "状态已更新",
      );
      await load();
    } catch (error) {
      message.error(getApiErrorMessage(error, "状态更新失败，请稍后重试"));
    }
  }

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>IPO 上架管理</Title>
          <Paragraph type="secondary">
            超级管理员只负责将产品上架到
            APP。客户申请的审核、分配和公布由业务员后台处理；上架不代表 IPO
            已上市。申购价由超管编辑并用于结算；草稿或尚无申购时可改申购价与认购期间；上市后实时行情仅用于展示价差。
          </Paragraph>
        </div>
        <Card>
          <Space
            style={{
              width: "100%",
              justifyContent: "space-between",
              marginBottom: 16,
            }}
          >
            <Button icon={<ReloadOutlined />} onClick={load} loading={loading}>
              刷新
            </Button>
            <Button
              type="primary"
              icon={<PlusOutlined />}
              onClick={() => setOpen(true)}
            >
              创建 IPO
            </Button>
          </Space>
          <Table<Ipo>
            rowKey="id"
            loading={loading}
            dataSource={items}
            scroll={{ x: 1280 }}
            columns={[
              {
                title: "IPO",
                width: 220,
                render: (_, r) => (
                  <Space orientation="vertical" size={0}>
                    <Text strong>{r.symbol}</Text>
                    <Text type="secondary">{r.companyName}</Text>
                  </Space>
                ),
              },
              { title: "申购价", dataIndex: "issuePrice", width: 110 },
              {
                title: "展示行情",
                dataIndex: "marketPrice",
                width: 110,
                render: (v: string | undefined, r) => v ?? r.issuePrice,
              },
              { title: "每手", dataIndex: "lotSize", width: 90 },
              { title: "可用股数", dataIndex: "availableShares", width: 120 },
              { title: "申购数", dataIndex: "applicationCount", width: 90 },
              {
                title: "状态",
                dataIndex: "status",
                width: 130,
                render: (v) => (
                  <Tag
                    color={
                      v === "PUBLISHED" || v === "OPEN" || v === "LISTED"
                        ? "green"
                        : v === "DRAFT"
                          ? "gold"
                          : "default"
                    }
                  >
                    {{
                      PUBLISHED: "已上架（APP 可认购）",
                      OPEN: "已上架（旧数据）",
                      DRAFT: "草稿",
                      CLOSED: "已下架",
                      LISTED: "已上市（展示实时行情，仍按申购价结算）",
                      ALLOTMENT_DONE: "分配已完成",
                    }[v as Ipo["status"]] ?? v}
                  </Tag>
                ),
              },
              {
                title: "申购期间",
                width: 310,
                render: (_, r) =>
                  `${new Date(r.openDate).toLocaleString()} — ${new Date(r.closeDate).toLocaleString()}`,
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
                      onClick={() => setStatus(r, "PUBLISHED")}
                    >
                      上架到 APP
                    </Button>
                    <Button
                      size="small"
                      danger
                      disabled={r.status !== "PUBLISHED" && r.status !== "OPEN"}
                      onClick={() => setStatus(r, "CLOSED")}
                    >
                      下架
                    </Button>
                  </Space>
                ),
              },
            ]}
          />
        </Card>
        <Modal
          title="创建并上架到 APP"
          open={open}
          onCancel={() => setOpen(false)}
          onOk={create}
          okText="创建并上架到 APP"
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
        </Modal>
        <Modal
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
        >
          <Paragraph type="secondary" style={{ marginTop: 0 }}>
            仅草稿或尚无申购时可修改。分配与入账始终按存储的申购价结算。
          </Paragraph>
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
        </Modal>
      </Space>
    </AdminShell>
  );
}
