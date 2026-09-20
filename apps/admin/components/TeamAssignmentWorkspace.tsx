"use client";

import {
  HistoryOutlined,
  ReloadOutlined,
  SwapOutlined,
  TeamOutlined,
  UserSwitchOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Drawer,
  Form,
  Input,
  Modal,
  Select,
  Space,
  Table,
  Tag,
  Tooltip,
  Typography,
  message,
} from "antd";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { api, getApiErrorMessage } from "@/lib/api";
import {
  newAssignmentIdempotencyKey,
  type AssignmentBusiness,
  type AssignmentHistoryRow,
  type AssignmentListResponse,
  type AssignmentPreview,
  type AssignmentStaff,
} from "@/lib/team-assignment";

const { Paragraph, Text, Title } = Typography;

export default function TeamAssignmentWorkspace() {
  const [data, setData] = useState<AssignmentListResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [managerId, setManagerId] = useState<string>("");
  const [expanded, setExpanded] = useState<string[]>([]);
  const [preview, setPreview] = useState<AssignmentPreview | null>(null);
  const [previewLoading, setPreviewLoading] = useState(false);
  const [transferOpen, setTransferOpen] = useState(false);
  const [reason, setReason] = useState("");
  const [saving, setSaving] = useState(false);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [historyRows, setHistoryRows] = useState<AssignmentHistoryRow[]>([]);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [historyTitle, setHistoryTitle] = useState("");
  const savingRef = useRef(false);
  const idempotencyKey = useRef(newAssignmentIdempotencyKey());
  const [form] = Form.useForm<{ reason: string }>();

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const { data: payload } = await api.get<AssignmentListResponse>(
        "/admin/business-assignments",
        { params: { search: search || undefined, managerId: managerId || undefined } },
      );
      setData(payload);
    } catch (err) {
      setError(getApiErrorMessage(err, "团队归属列表加载失败，请重试。"));
    } finally {
      setLoading(false);
    }
  }, [managerId, search]);

  useEffect(() => {
    void load();
  }, [load]);

  const pickerManagers = useMemo(
    () => data?.managerOptions ?? data?.managers ?? [],
    [data],
  );
  const managerFilterOptions = useMemo(
    () =>
      pickerManagers.map((row) => ({
        value: row.id,
        label: `${row.fullName}（${row.employeeNo || row.id.slice(0, 8)}）`,
      })),
    [pickerManagers],
  );

  async function openPreview(business: AssignmentBusiness, newManagerId: string) {
    setPreviewLoading(true);
    setError("");
    try {
      const { data: payload } = await api.post<AssignmentPreview>(
        "/admin/business-assignments/preview",
        { businessUserId: business.id, newManagerId },
      );
      setPreview(payload);
      idempotencyKey.current = newAssignmentIdempotencyKey();
      setReason("");
      form.resetFields();
    } catch (err) {
      setError(getApiErrorMessage(err, "影响预览失败，请重试。"));
    } finally {
      setPreviewLoading(false);
    }
  }

  async function openHistory(business: AssignmentStaff) {
    setHistoryOpen(true);
    setHistoryTitle(`${business.fullName} 的归属历史`);
    setHistoryLoading(true);
    try {
      const { data: rows } = await api.get<AssignmentHistoryRow[]>(
        `/admin/business-assignments/${business.id}/history`,
      );
      setHistoryRows(rows);
    } catch (err) {
      setError(getApiErrorMessage(err, "归属历史加载失败，请重试。"));
      setHistoryOpen(false);
    } finally {
      setHistoryLoading(false);
    }
  }

  async function confirmTransfer() {
    if (!preview || savingRef.current) return;
    const note = reason.trim();
    if (note.length < 4) {
      message.error("请填写至少 4 个字的变更原因");
      return;
    }
    savingRef.current = true;
    setSaving(true);
    try {
      await api.post("/admin/business-assignments/transfer", {
        businessUserId: preview.business.id,
        newManagerId: preview.newManager.id,
        reason: note,
        expectedCurrentManagerId: preview.currentManager?.id ?? null,
        idempotencyKey: idempotencyKey.current,
      });
      message.success("业务员归属已更新。客户仍归属于原业务员。");
      setTransferOpen(false);
      setPreview(null);
      await load();
    } catch (err) {
      message.error(getApiErrorMessage(err, "归属变更失败，请刷新后重试。"));
    } finally {
      savingRef.current = false;
      setSaving(false);
    }
  }

  const businessColumns = (managers: AssignmentStaff[]) => [
    { title: "员工编号", dataIndex: "employeeNo", render: (value: string | null) => value || "-" },
    { title: "业务员", dataIndex: "fullName" },
    {
      title: "当前管理员",
      render: (_: unknown, row: AssignmentBusiness) => {
        const manager = managers.find((item) => item.id === row.currentManagerId);
        return manager ? manager.fullName : "未归属";
      },
    },
    { title: "客户数", dataIndex: "clientCount" },
    { title: "VIP 客户", dataIndex: "vipClientCount" },
    {
      title: "状态",
      dataIndex: "status",
      render: (status: string) => <Tag>{status === "ACTIVE" ? "正常" : status}</Tag>,
    },
    {
      title: "操作",
      render: (_: unknown, row: AssignmentBusiness) => (
        <Space wrap>
          <Tooltip title="查看归属历史">
            <Button
              size="small"
              icon={<HistoryOutlined aria-hidden />}
              aria-label={`查看 ${row.fullName} 的归属历史`}
              onClick={() => void openHistory(row)}
            >
              历史
            </Button>
          </Tooltip>
          <TransferPicker
            managers={pickerManagers.filter((item) => item.id !== row.currentManagerId && item.status === "ACTIVE")}
            onSelect={(id) => void openPreview(row, id)}
            label={row.currentManagerId ? "转移" : "分配"}
            name={row.fullName}
          />
        </Space>
      ),
    },
  ];

  return (
    <Space direction="vertical" size={16} style={{ width: "100%" }} className="assignment-workspace">
      <div>
        <Title level={3} style={{ marginBottom: 4 }}>团队归属管理</Title>
        <Paragraph type="secondary" style={{ marginBottom: 0 }}>
          仅超级管理员可以把业务员分配或转移到管理员。转移只改管理员—业务员归属，不改客户归属、VIP、资金或交易。
        </Paragraph>
      </div>
      {error ? <Alert type="error" showIcon title={error} action={<Button onClick={() => void load()}>重试</Button>} /> : null}
      <Space wrap>
        <Input.Search
          allowClear
          placeholder="搜索管理员或业务员"
          aria-label="搜索管理员或业务员"
          onSearch={setSearch}
          style={{ width: 260 }}
        />
        <Select
          allowClear
          placeholder="按管理员筛选"
          aria-label="按管理员筛选"
          style={{ minWidth: 220 }}
          value={managerId || undefined}
          options={[{ value: "unassigned", label: "未归属业务员" }, ...managerFilterOptions]}
          onChange={(value) => setManagerId(value || "")}
        />
        <Button icon={<ReloadOutlined aria-hidden />} aria-label="刷新团队归属" onClick={() => void load()} loading={loading}>
          刷新
        </Button>
      </Space>
      <Space wrap className="ops-stat-strip">
        <Card size="small">管理员 {data?.totals.managerCount ?? 0}</Card>
        <Card size="small">业务员 {data?.totals.businessCount ?? 0}</Card>
        <Card size="small">未归属 {data?.totals.unassignedCount ?? 0}</Card>
        <Card size="small">客户 {data?.totals.clientCount ?? 0}</Card>
      </Space>
      {(!data || (!data.unassigned.length && !data.managers.length)) && !loading ? (
        <Alert type="info" showIcon title="暂无团队归属数据" />
      ) : null}
      {managerId === "unassigned" || managerId === "" ? (
        <Card
          title={<span><TeamOutlined aria-hidden /> 未归属业务员</span>}
          className="assignment-tree"
        >
          <Table<AssignmentBusiness>
            rowKey="id"
            loading={loading}
            pagination={false}
            dataSource={data?.unassigned ?? []}
            locale={{ emptyText: "没有未归属业务员" }}
            columns={businessColumns(pickerManagers)}
            scroll={{ x: 720 }}
          />
        </Card>
      ) : null}
      {managerId === "unassigned" ? null : (
        <Card title="管理员团队" className="assignment-tree">
        <Table<AssignmentStaff>
          rowKey="id"
          loading={loading}
          pagination={false}
          dataSource={data?.managers ?? []}
          expandable={{
            expandedRowKeys: expanded,
            onExpandedRowsChange: (keys) => setExpanded(keys.map(String)),
            expandedRowRender: (manager) => (
              <Table<AssignmentBusiness>
                rowKey="id"
                pagination={false}
                size="small"
                dataSource={(manager.businesses ?? []) as AssignmentBusiness[]}
                columns={businessColumns(pickerManagers)}
                locale={{ emptyText: "该管理员名下暂无业务员" }}
              />
            ),
          }}
          columns={[
            { title: "员工编号", dataIndex: "employeeNo", render: (value: string | null) => value || "-" },
            { title: "管理员", dataIndex: "fullName" },
            { title: "业务员数", dataIndex: "businessCount" },
            { title: "客户数", dataIndex: "clientCount" },
            { title: "VIP 客户", dataIndex: "vipClientCount" },
            {
              title: "状态",
              dataIndex: "status",
              render: (status: string) => <Tag>{status === "ACTIVE" ? "正常" : status}</Tag>,
            },
          ]}
          scroll={{ x: 640 }}
        />
        </Card>
      )}
      <Drawer
        title="转移影响预览"
        open={!!preview}
        onClose={() => !saving && setPreview(null)}
        width={Math.min(480, typeof window === "undefined" ? 480 : window.innerWidth)}
        className="assignment-drawer"
        extra={
          preview ? (
            <Button type="primary" onClick={() => setTransferOpen(true)}>
              继续确认
            </Button>
          ) : null
        }
      >
        {previewLoading ? <Paragraph>正在生成预览…</Paragraph> : null}
        {preview ? (
          <Space direction="vertical" size={12} style={{ width: "100%" }}>
            <Text>业务员：{preview.business.fullName}（{preview.business.employeeNo || "-"}）</Text>
            <Text>当前管理员：{preview.currentManager?.fullName ?? "未归属"}</Text>
            <Text>目标管理员：{preview.newManager.fullName}</Text>
            <Text>客户数量：{preview.clientCount}</Text>
            <Text>VIP 客户数量：{preview.vipClientCount}</Text>
            {preview.warnings.map((item) => (
              <Alert key={item} type="warning" showIcon message={item} />
            ))}
          </Space>
        ) : null}
      </Drawer>
      <Modal
        title="确认归属变更"
        open={transferOpen}
        onCancel={() => !saving && setTransferOpen(false)}
        onOk={() => void confirmTransfer()}
        confirmLoading={saving}
        okText="确认转移"
        cancelText="取消"
        className="assignment-dialog"
        okButtonProps={{ disabled: saving }}
      >
        {preview ? (
          <Space direction="vertical" size={8} style={{ width: "100%" }}>
            <Alert
              type="info"
              showIcon
              message="客户仍归属于该业务员，旧管理员将失去团队可见性。"
            />
            <Text>业务员：{preview.business.fullName}</Text>
            <Text>当前管理员：{preview.currentManager?.fullName ?? "未归属"}</Text>
            <Text>目标管理员：{preview.newManager.fullName}</Text>
            <Text>客户数量：{preview.clientCount} · VIP 客户数量：{preview.vipClientCount}</Text>
            <Form form={form} layout="vertical">
              <Form.Item name="reason" label="变更原因" rules={[{ required: true, min: 4, max: 240 }]}>
                <Input.TextArea
                  rows={3}
                  value={reason}
                  onChange={(event) => setReason(event.target.value)}
                  maxLength={240}
                />
              </Form.Item>
            </Form>
          </Space>
        ) : null}
      </Modal>
      <Drawer
        title={historyTitle}
        open={historyOpen}
        onClose={() => setHistoryOpen(false)}
        width={Math.min(560, typeof window === "undefined" ? 560 : window.innerWidth)}
        className="assignment-history"
      >
        <Table<AssignmentHistoryRow>
          rowKey="id"
          loading={historyLoading}
          pagination={false}
          dataSource={historyRows}
          locale={{ emptyText: "暂无归属历史" }}
          columns={[
            { title: "时间", dataIndex: "createdAt", render: (value: string) => new Date(value).toLocaleString() },
            { title: "原管理员", dataIndex: "previousManagerName", render: (value: string | null) => value || "未归属" },
            { title: "新管理员", dataIndex: "newManagerName" },
            { title: "原因", dataIndex: "reason" },
            { title: "客户数快照", dataIndex: "clientCountAtChange" },
          ]}
        />
      </Drawer>
    </Space>
  );
}

function TransferPicker({
  managers,
  onSelect,
  label,
  name,
}: {
  managers: AssignmentStaff[];
  onSelect: (managerId: string) => void;
  label: string;
  name: string;
}) {
  const [open, setOpen] = useState(false);
  const [target, setTarget] = useState<string>();
  return (
    <>
      <Tooltip title={`${label} ${name}`}>
        <Button
          size="small"
          icon={label === "转移" ? <SwapOutlined aria-hidden /> : <UserSwitchOutlined aria-hidden />}
          aria-label={`${label}业务员 ${name}`}
          onClick={() => {
            setTarget(undefined);
            setOpen(true);
          }}
        >
          {label}
        </Button>
      </Tooltip>
      <Modal
        title={`选择目标管理员（${name}）`}
        open={open}
        onCancel={() => setOpen(false)}
        onOk={() => {
          if (!target) {
            message.error("请选择目标管理员");
            return;
          }
          setOpen(false);
          onSelect(target);
        }}
        okText="查看影响预览"
        cancelText="取消"
      >
        <Select
          showSearch
          optionFilterProp="label"
          aria-label={`为 ${name} 选择目标管理员`}
          style={{ width: "100%" }}
          placeholder="选择管理员"
          value={target}
          options={managers.map((row) => ({
            value: row.id,
            label: `${row.fullName}（${row.employeeNo || "-"}）`,
          }))}
          onChange={setTarget}
        />
      </Modal>
    </>
  );
}
