"use client";

import { api } from "@/lib/api";
import {
  Alert,
  Button,
  Card,
  Descriptions,
  Drawer,
  Empty,
  Input,
  Modal,
  Space,
  Table,
  Tag,
  Typography,
  message,
} from "antd";
import { useCallback, useEffect, useState } from "react";

type Run = {
  id: string;
  status: string;
  startedAt: string;
  completedAt?: string | null;
  durationMs?: number | null;
  issueCount: number;
  errorSummary?: string | null;
};
type Issue = {
  id: string;
  checkType: string;
  severity: string;
  entityType: string;
  entityId?: string | null;
  summary: string;
  details?: unknown;
  acknowledgedAt?: string | null;
  acknowledgeNote?: string | null;
};
type RunDetail = Run & { issues: Issue[] };

const statusColor: Record<string, string> = {
  COMPLETED: "success",
  FAILED: "error",
  RUNNING: "processing",
  SKIPPED: "default",
};

export default function ReconciliationWorkspace() {
  const [runs, setRuns] = useState<Run[]>([]);
  const [loading, setLoading] = useState(true);
  const [detail, setDetail] = useState<RunDetail | null>(null);
  const [selectedIssue, setSelectedIssue] = useState<Issue | null>(null);
  const [note, setNote] = useState("");
  const [saving, setSaving] = useState(false);

  const loadRuns = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await api.get("/admin/reconciliation");
      setRuns(data.items ?? []);
    } catch {
      message.error("无法加载对账记录，请稍后重试");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadRuns();
  }, [loadRuns]);

  const openRun = async (id: string) => {
    try {
      const { data } = await api.get(`/admin/reconciliation/${id}`);
      setDetail(data);
    } catch {
      message.error("无法加载对账详情");
    }
  };

  const acknowledge = async () => {
    if (!selectedIssue || note.trim().length < 3) return;
    setSaving(true);
    try {
      await api.patch(
        `/admin/reconciliation/issues/${selectedIssue.id}/acknowledge`,
        {
          note: note.trim(),
        },
      );
      message.success("已记录确认，不会修改任何资金或持仓数据");
      setSelectedIssue(null);
      setNote("");
      if (detail) await openRun(detail.id);
    } catch {
      message.error("确认失败，请刷新后重试");
    } finally {
      setSaving(false);
    }
  };

  return (
    <Space orientation="vertical" size="middle" style={{ width: "100%" }}>
      <Alert
        type="info"
        showIcon
        message="只读安全边界"
        description="此工作台没有修正余额、调整持仓或重放交易的入口。异常必须通过原业务流程调查和处理。"
      />
      <Card>
        <Table<Run>
          rowKey="id"
          loading={loading}
          dataSource={runs}
          pagination={{ pageSize: 25 }}
          locale={{ emptyText: <Empty description="暂无对账运行记录" /> }}
          columns={[
            {
              title: "开始时间",
              dataIndex: "startedAt",
              render: (value: string) => new Date(value).toLocaleString(),
            },
            {
              title: "状态",
              dataIndex: "status",
              render: (value: string) => (
                <Tag color={statusColor[value]}>{value}</Tag>
              ),
            },
            { title: "异常数", dataIndex: "issueCount" },
            {
              title: "耗时",
              dataIndex: "durationMs",
              render: (value?: number) => (value == null ? "—" : `${value} ms`),
            },
            {
              title: "操作",
              render: (_, run) => (
                <Button onClick={() => void openRun(run.id)}>查看详情</Button>
              ),
            },
          ]}
        />
      </Card>
      <Drawer
        width={760}
        title="对账详情"
        open={Boolean(detail)}
        onClose={() => setDetail(null)}
      >
        {detail ? (
          <Space orientation="vertical" size="middle" style={{ width: "100%" }}>
            <Descriptions bordered size="small" column={2}>
              <Descriptions.Item label="运行编号">
                {detail.id}
              </Descriptions.Item>
              <Descriptions.Item label="状态">
                {detail.status}
              </Descriptions.Item>
              <Descriptions.Item label="异常数">
                {detail.issueCount}
              </Descriptions.Item>
              <Descriptions.Item label="耗时">
                {detail.durationMs ?? "—"} ms
              </Descriptions.Item>
            </Descriptions>
            {detail.errorSummary ? (
              <Alert type="error" message={detail.errorSummary} />
            ) : null}
            <Table<Issue>
              rowKey="id"
              dataSource={detail.issues}
              pagination={false}
              columns={[
                { title: "检查项", dataIndex: "checkType" },
                {
                  title: "对象",
                  render: (_, issue) =>
                    `${issue.entityType}${issue.entityId ? ` · ${issue.entityId}` : ""}`,
                },
                { title: "说明", dataIndex: "summary" },
                {
                  title: "状态",
                  render: (_, issue) =>
                    issue.acknowledgedAt ? (
                      <Tag color="success">已确认</Tag>
                    ) : (
                      <Tag color="warning">待调查</Tag>
                    ),
                },
                {
                  title: "操作",
                  render: (_, issue) =>
                    issue.acknowledgedAt ? (
                      <Typography.Text type="secondary">
                        {issue.acknowledgeNote}
                      </Typography.Text>
                    ) : (
                      <Button onClick={() => setSelectedIssue(issue)}>
                        记录确认
                      </Button>
                    ),
                },
              ]}
              expandable={{
                expandedRowRender: (issue) => (
                  <pre style={{ whiteSpace: "pre-wrap", margin: 0 }}>
                    {JSON.stringify(issue.details ?? {}, null, 2)}
                  </pre>
                ),
              }}
            />
          </Space>
        ) : null}
      </Drawer>
      <Modal
        title="确认已知异常"
        open={Boolean(selectedIssue)}
        okText="记录确认"
        cancelText="取消"
        okButtonProps={{ disabled: note.trim().length < 3, loading: saving }}
        onOk={() => void acknowledge()}
        onCancel={() => {
          setSelectedIssue(null);
          setNote("");
        }}
      >
        <Alert
          type="warning"
          showIcon
          message="此操作仅留下审计记录，不会修正余额或持仓。"
        />
        <Input.TextArea
          style={{ marginTop: 16 }}
          rows={4}
          maxLength={500}
          showCount
          value={note}
          onChange={(event) => setNote(event.target.value)}
          placeholder="填写调查结论或后续处理编号（至少 3 个字符）"
        />
      </Modal>
    </Space>
  );
}
