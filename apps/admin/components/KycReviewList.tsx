"use client";

import {
  EyeOutlined,
  ReloadOutlined,
  SafetyCertificateOutlined,
} from "@ant-design/icons";
import { Alert, Button, Card, Empty, Segmented, Space, Table, Tag, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useMemo, useState } from "react";

import KycStatusTag from "@/components/KycStatusTag";
import {
  KYC_REVIEW_COPY,
  canReviewKyc,
  countKycByStatus,
  filterKycList,
  formatKycDate,
  type KycStatusFilter,
  type KycSubmissionView,
} from "@/lib/kyc-review";

const { Text } = Typography;

type Props = {
  items: KycSubmissionView[];
  loading: boolean;
  error: string;
  onRetry: () => void;
  onOpen: (item: KycSubmissionView) => void;
  includeOwner?: boolean;
  busy?: boolean;
};

export default function KycReviewList({
  items,
  loading,
  error,
  onRetry,
  onOpen,
  includeOwner = false,
  busy = false,
}: Props) {
  const [filter, setFilter] = useState<KycStatusFilter>("ALL");
  const counts = useMemo(() => countKycByStatus(items), [items]);
  const visible = useMemo(() => filterKycList(items, filter), [items, filter]);

  const columns: ColumnsType<KycSubmissionView> = [];
  if (includeOwner) {
    columns.push({
      title: "所属业务员",
      dataIndex: "ownerStaffName",
      render: (value: string | undefined) => value || "-",
    });
  }
  columns.push(
    {
      title: "客户",
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{record.fullName || "未命名客户"}</Text>
          <Text type="secondary">
            {record.phone?.startsWith("+")
              ? record.phone
              : `+91 ${record.phone || "-"}`}
          </Text>
        </Space>
      ),
    },
    {
      title: "提交类型",
      dataIndex: "documentType",
      render: (value: string) => <Tag>{value || "-"}</Tag>,
    },
    {
      title: KYC_REVIEW_COPY.filenameHint,
      dataIndex: "recognizedType",
      render: (value: string | null | undefined) => <Tag>{value || "-"}</Tag>,
    },
    {
      title: "已提交文件",
      render: (_, record) => (
        <Space size={4} wrap>
          <Tag>正面</Tag>
          {record.backFileName ? <Tag>反面</Tag> : null}
          {record.hasSelfie ? <Tag>自拍</Tag> : null}
          {record.hasSignature ? <Tag>签名</Tag> : null}
        </Space>
      ),
    },
    {
      title: "状态",
      dataIndex: "status",
      render: (_, record) => (
        <KycStatusTag status={record.status} reviewNote={record.reviewNote} />
      ),
    },
    {
      title: "提交时间",
      dataIndex: "createdAt",
      render: (value: string) => formatKycDate(value),
    },
    {
      title: "操作",
      fixed: "right",
      width: 92,
      render: (_, record) => {
        const pending = canReviewKyc(record.status);
        return (
          <Button
            type={pending ? "primary" : "default"}
            size="small"
            icon={
              pending ? (
                <SafetyCertificateOutlined aria-hidden />
              ) : (
                <EyeOutlined aria-hidden />
              )
            }
            aria-label={
              pending
                ? `审核 ${record.fullName || "客户"} 的 KYC 提交`
                : `查看 ${record.fullName || "客户"} 的 KYC 提交`
            }
            disabled={busy}
            onClick={() => onOpen(record)}
          >
            {pending ? KYC_REVIEW_COPY.reviewAction : KYC_REVIEW_COPY.viewAction}
          </Button>
        );
      },
    },
  );

  return (
    <Space orientation="vertical" size="middle" style={{ width: "100%" }} className="kyc-review-workspace">
      {error ? (
        <Alert
          type="error"
          showIcon
          role="alert"
          className="kyc-alert"
          title={error}
          action={
            <Button
              size="small"
              icon={<ReloadOutlined aria-hidden />}
              aria-label="重新加载 KYC 列表"
              onClick={onRetry}
            >
              重试
            </Button>
          }
        />
      ) : null}

      <div className="ops-stat-strip" aria-label="KYC 状态统计">
        <div className="ops-stat-pill">
          <span>全部</span>
          <strong>{counts.ALL}</strong>
        </div>
        <div className="ops-stat-pill">
          <span>待审核</span>
          <strong>{counts.PENDING}</strong>
        </div>
        <div className="ops-stat-pill">
          <span>已通过</span>
          <strong>{counts.APPROVED}</strong>
        </div>
        <div className="ops-stat-pill">
          <span>已拒绝</span>
          <strong>{counts.REJECTED}</strong>
        </div>
      </div>

      <Card className="kyc-list-card">
        <div className="ops-toolbar">
          <Segmented
            value={filter}
            aria-label="按 KYC 状态筛选"
            onChange={(value) => setFilter(value as KycStatusFilter)}
            options={[
              { label: "全部", value: "ALL" },
              { label: "待审核", value: "PENDING" },
              { label: "已通过", value: "APPROVED" },
              { label: "已拒绝", value: "REJECTED" },
            ]}
          />
          <Button
            icon={<ReloadOutlined aria-hidden />}
            loading={loading}
            aria-label="刷新 KYC 列表"
            onClick={onRetry}
          >
            刷新
          </Button>
        </div>
        <Table<KycSubmissionView>
          rowKey="id"
          loading={loading}
          columns={columns}
          dataSource={visible}
          scroll={{ x: 960 }}
          locale={{
            emptyText: (
              <Empty
                image={Empty.PRESENTED_IMAGE_SIMPLE}
                description={
                  loading
                    ? KYC_REVIEW_COPY.loading
                    : items.length
                      ? KYC_REVIEW_COPY.filteredEmpty
                      : KYC_REVIEW_COPY.empty
                }
              />
            ),
          }}
        />
      </Card>
    </Space>
  );
}
