"use client";

import { HistoryOutlined, ReloadOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Modal, Select, Space, Table, Tag, Typography, Input } from "antd";
import { useCallback, useEffect, useRef, useState } from "react";
import { api, getApiErrorMessage } from "@/lib/api";
import VipSuggestionTag from "@/components/VipSuggestionTag";
import {
  suggestionLabel,
  VIP_TIERS,
  vipTierLabel,
  type VipClientRow,
  type VipHistoryRow,
} from "@/lib/vip";

const { Paragraph } = Typography;

type Props = {
  endpoint: string;
  historyEndpoint: (userId: string) => string;
  adjustEndpoint?: (userId: string) => string;
  allowAdjust?: boolean;
  emptyText: string;
};

export default function VipClientsWorkspace({
  endpoint,
  historyEndpoint,
  adjustEndpoint,
  allowAdjust = false,
  emptyText,
}: Props) {
  const [rows, setRows] = useState<VipClientRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [configured, setConfigured] = useState(true);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [historyRows, setHistoryRows] = useState<VipHistoryRow[]>([]);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [adjusting, setAdjusting] = useState<VipClientRow | null>(null);
  const [tier, setTier] = useState("STANDARD");
  const [reason, setReason] = useState("");
  const [saving, setSaving] = useState(false);
  const savingRef = useRef(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const { data } = await api.get<{ suggestionConfigured?: boolean; clients: VipClientRow[] }>(endpoint);
      setRows(data.clients ?? []);
      setConfigured(data.suggestionConfigured !== false);
    } catch (err) {
      setError(getApiErrorMessage(err, "VIP 客户列表加载失败，请重试。"));
    } finally {
      setLoading(false);
    }
  }, [endpoint]);

  useEffect(() => {
    void load();
  }, [load]);

  async function openHistory(userId: string) {
    setHistoryOpen(true);
    setHistoryLoading(true);
    try {
      const { data } = await api.get<VipHistoryRow[]>(historyEndpoint(userId));
      setHistoryRows(data);
    } catch (err) {
      setError(getApiErrorMessage(err, "等级历史加载失败，请重试。"));
      setHistoryOpen(false);
    } finally {
      setHistoryLoading(false);
    }
  }

  async function saveAdjust() {
    if (!adjusting || !adjustEndpoint || savingRef.current) return;
    if (reason.trim().length < 4) {
      setError("请填写至少 4 个字符的调整原因。");
      return;
    }
    Modal.confirm({
      title: "确认调整客户 VIP 等级？",
      content: "该操作只修改会员展示等级，不会改变交易权限、资金限额或费用。建议等级仅供参考，仍由业务员手动确认。",
      okText: "确认调整",
      cancelText: "取消",
      onOk: async () => {
        savingRef.current = true;
        setSaving(true);
        setError("");
        try {
          await api.patch(adjustEndpoint(adjusting.userId), { tier, reason: reason.trim() });
          setAdjusting(null);
          setReason("");
          await load();
        } catch (err) {
          setError(getApiErrorMessage(err, "等级调整失败，请重试。"));
        } finally {
          savingRef.current = false;
          setSaving(false);
        }
      },
    });
  }

  return (
    <Space direction="vertical" size={16} style={{ width: "100%" }}>
      {!configured ? (
        <Alert type="info" showIcon message="累计充值门槛尚未配置，因此不会生成建议等级。" />
      ) : null}
      {error ? (
        <Alert type="error" showIcon message={error} action={<Button onClick={() => void load()}>重试</Button>} />
      ) : null}
      <Card>
        <Button icon={<ReloadOutlined />} onClick={() => void load()} loading={loading} style={{ marginBottom: 12 }}>
          刷新
        </Button>
        <Table
          rowKey="userId"
          loading={loading}
          dataSource={rows}
          locale={{ emptyText }}
          pagination={{ pageSize: 20 }}
          scroll={{ x: 980 }}
          columns={[
            { title: "客户", dataIndex: "displayName", render: (value, row) => `${value} · ${row.clientId ?? "-"}` },
            { title: "手机号", dataIndex: "maskedPhone", width: 120, render: (value) => value || "-" },
            {
              title: "所属业务员",
              dataIndex: ["assignedBusiness", "fullName"],
              render: (_: unknown, row) =>
                row.assignedBusiness
                  ? `${row.assignedBusiness.fullName}${row.assignedBusiness.employeeNo ? ` · ${row.assignedBusiness.employeeNo}` : ""}`
                  : "-",
            },
            {
              title: "当前等级",
              dataIndex: "currentTier",
              render: (value) => <Tag>{vipTierLabel(value)}</Tag>,
            },
            { title: "累计确认充值", dataIndex: "cumulativeConfirmedDeposit" },
            {
              title: "建议等级",
              dataIndex: "suggestedTier",
              render: (value) => vipTierLabel(value),
            },
            {
              title: "建议状态",
              dataIndex: "suggestionStatus",
              render: (value) => <VipSuggestionTag status={value} />,
            },
            {
              title: "操作",
              key: "actions",
              render: (_, row) => (
                <Space>
                  <Button size="small" icon={<HistoryOutlined />} onClick={() => void openHistory(row.userId)}>
                    历史
                  </Button>
                  {allowAdjust ? (
                    <Button
                      size="small"
                      type="primary"
                      onClick={() => {
                        setAdjusting(row);
                        setTier(row.currentTier);
                        setReason("");
                      }}
                    >
                      调整等级
                    </Button>
                  ) : null}
                </Space>
              ),
            },
          ]}
        />
      </Card>
      <Modal
        title="VIP 等级调整历史"
        open={historyOpen}
        footer={null}
        onCancel={() => setHistoryOpen(false)}
        width={720}
      >
        <Table
          rowKey="id"
          loading={historyLoading}
          dataSource={historyRows}
          pagination={false}
          locale={{ emptyText: "暂无等级调整记录" }}
          columns={[
            { title: "时间", dataIndex: "createdAt", render: (value, row) => value || row.changedAt },
            { title: "原等级", dataIndex: "previousTier", render: vipTierLabel },
            { title: "新等级", dataIndex: "newTier", render: vipTierLabel },
            { title: "当时建议", dataIndex: "suggestedTierAtChange", render: vipTierLabel },
            { title: "累计充值快照", dataIndex: "cumulativeDepositAtChange" },
            { title: "原因", dataIndex: "reason" },
            { title: "操作人", dataIndex: ["changedBy", "fullName"] },
          ]}
        />
      </Modal>
      <Modal
        title="调整客户 VIP 等级"
        open={adjusting !== null}
        confirmLoading={saving}
        okText="下一步确认"
        cancelText="取消"
        onOk={() => void saveAdjust()}
        onCancel={() => {
          if (!savingRef.current) setAdjusting(null);
        }}
        closable={!saving}
        maskClosable={!saving}
      >
        <Paragraph>
          {adjusting?.displayName} · 当前 {vipTierLabel(adjusting?.currentTier)} · 建议{" "}
          {vipTierLabel(adjusting?.suggestedTier)}（{suggestionLabel(adjusting?.suggestionStatus)}）
        </Paragraph>
        <Paragraph type="secondary">
          累计确认充值 {adjusting?.cumulativeConfirmedDeposit ?? "0.00"}。建议仅供参考，不会自动改级。
        </Paragraph>
        <Select
          aria-label="新 VIP 等级"
          style={{ width: "100%", marginBottom: 12 }}
          value={tier}
          options={[...VIP_TIERS]}
          onChange={setTier}
          disabled={saving}
        />
        <Input.TextArea
          aria-label="调整原因"
          rows={3}
          value={reason}
          disabled={saving}
          placeholder="请填写调整原因"
          onChange={(event) => setReason(event.target.value)}
        />
      </Modal>
    </Space>
  );
}
