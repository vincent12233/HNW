"use client";

import {
  HistoryOutlined,
  ProfileOutlined,
  ReloadOutlined,
  SettingOutlined,
  AuditOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Descriptions,
  Drawer,
  Modal,
  Select,
  Skeleton,
  Space,
  Table,
  Tag,
  Typography,
  Input,
} from "antd";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { api, getApiErrorMessage } from "@/lib/api";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import VipSuggestionTag from "@/components/VipSuggestionTag";
import {
  filterVipClients,
  formatVipTimestamp,
  suggestionLabel,
  summarizeVipClients,
  vipBusinessBreakdown,
  vipBusinessOptions,
  VIP_TIERS,
  vipTierLabel,
  type VipClientRow,
  type VipHistoryRow,
  type VipSuggestionStatus,
} from "@/lib/vip";

const { Paragraph, Text } = Typography;

type Props = {
  endpoint: string;
  historyEndpoint: (userId: string) => string;
  adjustEndpoint?: (userId: string) => string;
  allowAdjust?: boolean;
  emptyText: string;
  showAdminLinks?: boolean;
  showBusinessBreakdown?: boolean;
};

export default function VipClientsWorkspace({
  endpoint,
  historyEndpoint,
  adjustEndpoint,
  allowAdjust = false,
  emptyText,
  showAdminLinks = false,
  showBusinessBreakdown = false,
}: Props) {
  const [rows, setRows] = useState<VipClientRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [configured, setConfigured] = useState(true);
  const [tierFilter, setTierFilter] = useState<string>();
  const [businessFilter, setBusinessFilter] = useState<string>();
  const [statusFilter, setStatusFilter] = useState<VipSuggestionStatus | "KEEP">();
  const [historyOpen, setHistoryOpen] = useState(false);
  const [historyRows, setHistoryRows] = useState<VipHistoryRow[]>([]);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [detail, setDetail] = useState<VipClientRow | null>(null);
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

  const summary = useMemo(() => summarizeVipClients(rows), [rows]);
  const businessOptions = useMemo(() => vipBusinessOptions(rows), [rows]);
  const breakdown = useMemo(
    () => (showBusinessBreakdown ? vipBusinessBreakdown(rows) : []),
    [rows, showBusinessBreakdown],
  );
  const visibleRows = useMemo(
    () =>
      filterVipClients(rows, {
        tier: tierFilter,
        businessId: businessFilter,
        suggestionStatus: statusFilter,
      }),
    [rows, tierFilter, businessFilter, statusFilter],
  );

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
    <Space direction="vertical" size={16} style={{ width: "100%" }} className="vip-workspace">
      {!configured ? (
        <Alert type="info" showIcon message="累计充值门槛尚未配置，因此不会生成建议等级。" />
      ) : null}
      {error ? (
        <Alert type="error" showIcon message={error} action={<Button onClick={() => void load()}>重试</Button>} />
      ) : null}
      {showAdminLinks ? (
        <Space wrap>
          <Button icon={<SettingOutlined />} href="/vip-settings">
            门槛配置
          </Button>
          <Button icon={<HistoryOutlined />} href="/vip-history">
            变更历史
          </Button>
          <Button icon={<AuditOutlined />} href="/audit-logs">
            配置审计
          </Button>
        </Space>
      ) : null}
      {loading && rows.length === 0 && !error ? (
        <div className="vip-summary-skeleton" aria-label="正在加载 VIP 汇总">
          <Skeleton active title={false} paragraph={{ rows: 2 }} />
        </div>
      ) : null}
      {!error && rows.length > 0 ? (
        <>
          <Text type="secondary">以下数量来自当前 VIP 客户接口返回的完整列表，不是单独汇总接口。</Text>
          <div className="vip-summary-grid" aria-label="VIP 汇总">
            {VIP_TIERS.map((item) => (
              <div key={item.value} className="vip-summary-card">
                <span>{item.label}</span>
                <strong>{summary.byTier[item.value] ?? 0}</strong>
              </div>
            ))}
            <div className="vip-summary-card">
              <span>未配置门槛</span>
              <strong>{summary.notConfigured}</strong>
            </div>
            <div className="vip-summary-card">
              <span>建议升级</span>
              <strong>{summary.upgrade}</strong>
            </div>
            <div className="vip-summary-card">
              <span>建议降级</span>
              <strong>{summary.downgrade}</strong>
            </div>
            <div className="vip-summary-card">
              <span>保持当前</span>
              <strong>{summary.keepCurrent}</strong>
            </div>
          </div>
        </>
      ) : null}
      {showBusinessBreakdown && breakdown.length > 0 ? (
        <Card size="small" title="各业务员客户数量" className="vip-breakdown-card">
          <Table
            rowKey="id"
            size="small"
            pagination={false}
            dataSource={breakdown}
            columns={[
              { title: "业务员", dataIndex: "name" },
              { title: "客户数", dataIndex: "clientCount", width: 90 },
              {
                title: "等级分布",
                render: (_, row) =>
                  VIP_TIERS.map((item) => `${item.label.replace(/ .*/, "")} ${row.byTier[item.value] ?? 0}`).join(" · "),
              },
            ]}
          />
        </Card>
      ) : null}
      <Card>
        <Space wrap className="vip-toolbar">
          <Button icon={<ReloadOutlined />} onClick={() => void load()} loading={loading} aria-label="刷新 VIP 客户列表">
            刷新
          </Button>
          <Select
            allowClear
            aria-label="按当前等级筛选"
            placeholder="当前等级"
            style={{ minWidth: 160 }}
            value={tierFilter}
            options={[...VIP_TIERS]}
            onChange={setTierFilter}
          />
          <Select
            allowClear
            showSearch
            optionFilterProp="label"
            aria-label="按所属业务员筛选"
            placeholder="所属业务员"
            style={{ minWidth: 200 }}
            value={businessFilter}
            options={businessOptions}
            onChange={setBusinessFilter}
          />
          <Select
            allowClear
            aria-label="按建议状态筛选"
            placeholder="建议状态"
            style={{ minWidth: 160 }}
            value={statusFilter}
            options={[
              { value: "NOT_CONFIGURED", label: "未配置" },
              { value: "UPGRADE", label: "建议升级" },
              { value: "DOWNGRADE", label: "建议降级" },
              { value: "KEEP", label: "保持当前" },
            ]}
            onChange={setStatusFilter}
          />
        </Space>
        <Table
          rowKey="userId"
          loading={loading}
          dataSource={visibleRows}
          locale={{
            emptyText: error ? (
              <OpsErrorState description="VIP 客户列表未能加载" />
            ) : (
              <OpsEmpty description={emptyText} />
            ),
          }}
          pagination={{ pageSize: 20 }}
          scroll={{ x: 1180 }}
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
              title: "最后调整",
              dataIndex: "lastTierChangedAt",
              width: 170,
              render: (value) => formatVipTimestamp(value),
            },
            {
              title: "操作",
              key: "actions",
              render: (_, row) => (
                <Space>
                  <Button
                    size="small"
                    icon={<ProfileOutlined />}
                    aria-label={`查看 ${row.displayName} 的 VIP 详情`}
                    onClick={() => setDetail(row)}
                  >
                    详情
                  </Button>
                  <Button
                    size="small"
                    icon={<HistoryOutlined />}
                    aria-label={`查看 ${row.displayName} 的 VIP 历史`}
                    onClick={() => void openHistory(row.userId)}
                  >
                    历史
                  </Button>
                  {allowAdjust ? (
                    <Button
                      size="small"
                      type="primary"
                      aria-label={`调整 ${row.displayName} 的 VIP 等级`}
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
      <Drawer
        title="客户 VIP 详情"
        open={detail !== null}
        onClose={() => setDetail(null)}
        width={420}
        className="vip-detail-drawer"
        destroyOnClose
      >
        {detail ? (
          <Descriptions column={1} size="small">
            <Descriptions.Item label="客户">{detail.displayName}</Descriptions.Item>
            <Descriptions.Item label="客户编号">{detail.clientId ?? "-"}</Descriptions.Item>
            <Descriptions.Item label="手机号">{detail.maskedPhone || "-"}</Descriptions.Item>
            <Descriptions.Item label="所属业务员">
              {detail.assignedBusiness
                ? `${detail.assignedBusiness.fullName}${detail.assignedBusiness.employeeNo ? ` · ${detail.assignedBusiness.employeeNo}` : ""}`
                : "-"}
            </Descriptions.Item>
            <Descriptions.Item label="当前等级">{vipTierLabel(detail.currentTier)}</Descriptions.Item>
            <Descriptions.Item label="建议等级">{vipTierLabel(detail.suggestedTier)}</Descriptions.Item>
            <Descriptions.Item label="建议状态">
              <VipSuggestionTag status={detail.suggestionStatus} />
            </Descriptions.Item>
            <Descriptions.Item label="建议说明">
              <span className="vip-wrap-text">{detail.suggestionReason || "—"}</span>
            </Descriptions.Item>
            <Descriptions.Item label="累计确认充值">{detail.cumulativeConfirmedDeposit}</Descriptions.Item>
            <Descriptions.Item label="最后调整">{formatVipTimestamp(detail.lastTierChangedAt)}</Descriptions.Item>
          </Descriptions>
        ) : null}
      </Drawer>
      <Modal
        title="VIP 等级调整历史"
        open={historyOpen}
        footer={null}
        onCancel={() => setHistoryOpen(false)}
        width={720}
        className="vip-history-dialog"
      >
        <Table
          rowKey="id"
          loading={historyLoading}
          dataSource={historyRows}
          pagination={false}
          locale={{ emptyText: <OpsEmpty description="暂无等级调整记录" /> }}
          columns={[
            { title: "时间", dataIndex: "createdAt", render: (value, row) => value || row.changedAt },
            { title: "原等级", dataIndex: "previousTier", render: vipTierLabel },
            { title: "新等级", dataIndex: "newTier", render: vipTierLabel },
            { title: "当时建议", dataIndex: "suggestedTierAtChange", render: vipTierLabel },
            { title: "累计充值快照", dataIndex: "cumulativeDepositAtChange" },
            {
              title: "原因",
              dataIndex: "reason",
              render: (value) => <span className="vip-wrap-text">{value}</span>,
            },
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
        className="vip-adjust-dialog"
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
