"use client";

import { PlusOutlined, ReloadOutlined } from "@ant-design/icons";
import {
  Button,
  Card,
  DatePicker,
  Form,
  InputNumber,
  Modal,
  Select,
  Space,
  Switch,
  Table,
  Tag,
  Typography,
  message,
} from "antd";
import { useEffect, useMemo, useState } from "react";
import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;

type Instrument = {
  id: string;
  symbol: string;
  exchange: string;
  name: string;
  quote?: { lastPrice?: string | number | null } | null;
};

type Offer = {
  id: string;
  price: string;
  marketPrice?: string | null;
  transactionKey?: string | null;
  isActive: boolean;
  validFrom: string;
  validUntil: string;
  instrument: Instrument;
};

type PublishedOffer = Offer & { transactionKey: string };

export default function OtcOffersPage() {
  const [offers, setOffers] = useState<Offer[]>([]);
  const [instruments, setInstruments] = useState<Instrument[]>([]);
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [form] = Form.useForm();
  const selectedInstrumentId = Form.useWatch("instrumentId", form);

  const selectedInstrument = useMemo(
    () => instruments.find((item) => item.id === selectedInstrumentId) ?? null,
    [instruments, selectedInstrumentId],
  );

  const liveMarketPrice = useMemo(() => {
    const raw = selectedInstrument?.quote?.lastPrice;
    if (raw == null || raw === "") return null;
    const value = Number(raw);
    return Number.isFinite(value) ? value : null;
  }, [selectedInstrument]);

  async function load() {
    setLoading(true);
    try {
      const [offerResponse, instrumentResponse] = await Promise.all([
        api.get<Offer[]>("/otc/admin/offers"),
        api.get<{ data: Instrument[] }>("/admin/market/instruments?pageSize=100"),
      ]);
      setOffers(offerResponse.data ?? []);
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
    const settlementPrice = Number(values.price);
    if (!Number.isFinite(settlementPrice) || settlementPrice <= 0) {
      message.error("请填写有效的折扣结算价");
      return;
    }
    if (
      liveMarketPrice != null &&
      Number.isFinite(liveMarketPrice) &&
      settlementPrice > liveMarketPrice
    ) {
      message.error("折扣结算价不能高于实时行情");
      return;
    }
    const response = await api.post<PublishedOffer>("/otc/admin/offers", {
      instrumentId: values.instrumentId,
      price: settlementPrice.toFixed(4),
      validFrom: values.period[0].toISOString(),
      validUntil: values.period[1].toISOString(),
    });
    setOpen(false);
    form.resetFields();
    await load();
    Modal.success({
      title: "OTC 上架成功 · 新交易密钥",
      content: (
        <Space orientation="vertical">
          <Text>该 4 位交易密钥将在 OTC 列表中显示，下架后隐藏。</Text>
          <Title level={2} copyable style={{ margin: 0, letterSpacing: 8 }}>
            {response.data.transactionKey}
          </Title>
        </Space>
      ),
    });
  }

  async function toggle(record: Offer, isActive: boolean) {
    await api.patch(`/otc/admin/offers/${record.id}`, { isActive });
    await load();
  }

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>OTC 上架管理</Title>
          <Paragraph type="secondary">
            实时行情仅作参考；上架时填写折扣结算价（成交按此价格结算）。每次上架自动生成新的
            4 位交易密钥。
          </Paragraph>
        </div>
        <Card>
          <Space
            style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}
          >
            <Button icon={<ReloadOutlined />} onClick={load}>
              刷新
            </Button>
            <Button
              type="primary"
              icon={<PlusOutlined />}
              onClick={() => {
                form.resetFields();
                setOpen(true);
              }}
            >
              上架股票
            </Button>
          </Space>
          <Table
            rowKey="id"
            loading={loading}
            dataSource={offers}
            columns={[
              {
                title: "股票",
                render: (_: unknown, r: Offer) => (
                  <Space orientation="vertical" size={0}>
                    <Text strong>{r.instrument.symbol}</Text>
                    <Text type="secondary">
                      {r.instrument.exchange} · {r.instrument.name}
                    </Text>
                  </Space>
                ),
              },
              {
                title: "实时行情",
                render: (_: unknown, r: Offer) =>
                  r.marketPrice ? `₹${Number(r.marketPrice).toFixed(2)}` : "—",
              },
              {
                title: "折扣结算价",
                dataIndex: "price",
                render: (v: string) => `₹${Number(v).toFixed(2)}`,
              },
              {
                title: "交易密钥",
                render: (_: unknown, r: Offer) =>
                  r.isActive && r.transactionKey ? (
                    <Text code copyable>
                      {r.transactionKey}
                    </Text>
                  ) : (
                    <Text type="secondary">下架后隐藏</Text>
                  ),
              },
              {
                title: "开始时间",
                dataIndex: "validFrom",
                render: (v: string) => new Date(v).toLocaleString("zh-CN"),
              },
              {
                title: "结束时间",
                dataIndex: "validUntil",
                render: (v: string) => new Date(v).toLocaleString("zh-CN"),
              },
              {
                title: "状态",
                render: (_: unknown, r: Offer) => (
                  <Tag color={r.isActive ? "green" : "default"}>
                    {r.isActive ? "已上架" : "已下架"}
                  </Tag>
                ),
              },
              {
                title: "启用",
                render: (_: unknown, r: Offer) => (
                  <Switch checked={r.isActive} onChange={(v) => toggle(r, v)} />
                ),
              },
            ]}
          />
        </Card>
        <Modal
          title="上架 OTC 股票"
          open={open}
          onCancel={() => setOpen(false)}
          onOk={create}
          okText="上架并生成密钥"
          cancelText="取消"
        >
          <Form form={form} layout="vertical">
            <Form.Item name="instrumentId" label="股票" rules={[{ required: true }]}>
              <Select
                showSearch
                optionFilterProp="label"
                options={instruments.map((i) => ({
                  value: i.id,
                  label: `${i.exchange}:${i.symbol} · ${i.name}`,
                }))}
              />
            </Form.Item>
            <Form.Item label="实时行情（参考）">
              <Text>
                {liveMarketPrice != null && Number.isFinite(liveMarketPrice)
                  ? `₹${liveMarketPrice.toFixed(2)}`
                  : "选择股票后显示；上架前需有有效行情"}
              </Text>
            </Form.Item>
            <Form.Item
              name="price"
              label="折扣结算价（₹）"
              rules={[{ required: true, message: "请填写折扣结算价" }]}
              extra="客户成交按此价格结算，须低于或等于实时行情。"
            >
              <InputNumber
                min={0.0001}
                step={0.01}
                precision={4}
                style={{ width: "100%" }}
                placeholder="例如低于行情的折扣价"
              />
            </Form.Item>
            <Form.Item name="period" label="有效时间" rules={[{ required: true }]}>
              <DatePicker.RangePicker showTime style={{ width: "100%" }} />
            </Form.Item>
          </Form>
        </Modal>
      </Space>
    </AdminShell>
  );
}
