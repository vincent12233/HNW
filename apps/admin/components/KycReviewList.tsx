"use client";

import {
  EyeOutlined,
  ReloadOutlined,
  SafetyCertificateOutlined,
  SearchOutlined,
} from "@ant-design/icons";
import { Button, Input, Select, Space, Table, Tag, Tooltip } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useMemo, useState } from "react";

import KycStatusTag from "@/components/KycStatusTag";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsToolbar from "@/components/OpsToolbar";
import {
  KYC_REVIEW_COPY,
  canReviewKyc,
  countKycByStatus,
  filterKycList,
  kycHasReviewerFields,
  type KycStatusFilter,
  type KycSubmissionView,
} from "@/lib/kyc-review";
import {
  LOADED_FILTER_CAPTION,
  filterLoadedRows,
  maskOpsPhone,
  useDebouncedValue,
} from "@/lib/ops-directory";
import { formatOpsDateTime, OPS_TABLE_PAGINATION } from "@/lib/ops-format";
import { vipTierLabel } from "@/lib/vip";

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
  const [keyword, setKeyword] = useState("");
  const debouncedKeyword = useDebouncedValue(keyword);
  const counts = useMemo(() => countKycByStatus(items), [items]);
  const showReviewer = useMemo(() => kycHasReviewerFields(items), [items]);
  const showVip = useMemo(() => items.some((item) => Boolean(item.clientTier)), [items]);
  const visible = useMemo(
    () =>
      filterLoadedRows(
        filterKycList(items, filter),
        debouncedKeyword,
        (row) => [
          row.fullName,
          row.userId,
          row.id,
          row.documentType,
          row.reviewNote,
          row.ownerStaffName,
          row.recognizedType,
          maskOpsPhone(row.phone, ""),
        ],
      ),
    [debouncedKeyword, filter, items],
  );
  const hasFilters = keyword.trim() !== "" || filter !== "ALL";

  const columns: ColumnsType<KycSubmissionView> = [];
  if (includeOwner) {
    columns.push({
      title: "所属业务员",
      dataIndex: "ownerStaffName",
      width: 160,
      render: (value: string | undefined) => (
        <span className="kyc-wrap-text">{value || "—"}</span>
      ),
    });
  }
  columns.push(
    {
      title: "客户标识",
      key: "identity",
      width: 200,
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <span className="kyc-wrap-text" title={record.fullName}>
            {record.fullName || "未命名客户"}
          </span>
          <span className="ops-id" title={record.userId}>
            {record.userId}
          </span>
        </Space>
      ),
    },
    {
      title: "脱敏手机号",
      key: "phone",
      width: 140,
      render: (_, record) => maskOpsPhone(record.phone),
    },
    {
      title: "提交类型",
      dataIndex: "documentType",
      width: 120,
      render: (value: string) => <Tag>{value || "—"}</Tag>,
    },
    {
      title: KYC_REVIEW_COPY.filenameHint,
      dataIndex: "recognizedType",
      width: 120,
      render: (value: string | null | undefined) => <Tag>{value || "—"}</Tag>,
    },
    {
      title: "已提交文件",
      key: "files",
      width: 180,
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
      title: "KYC 状态",
      dataIndex: "status",
      width: 140,
      render: (_, record) => (
        <KycStatusTag status={record.status} reviewNote={record.reviewNote} />
      ),
    },
    {
      title: "审核备注摘要",
      dataIndex: "reviewNote",
      width: 220,
      render: (value?: string | null) => (
        <span className="kyc-wrap-text">{value?.trim() || "—"}</span>
      ),
    },
    {
      title: "提交时间",
      dataIndex: "createdAt",
      width: 180,
      render: (value: string) => formatOpsDateTime(value),
    },
  );
  if (showReviewer) {
    columns.push({
      title: "审核人 / 时间",
      key: "reviewer",
      width: 200,
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <span className="kyc-wrap-text">{record.reviewedByName || "—"}</span>
          <span>{formatOpsDateTime(record.reviewedAt)}</span>
        </Space>
      ),
    });
  }
  if (showVip) {
    columns.push({
      title: "VIP",
      key: "clientTier",
      width: 140,
      render: (_, record) =>
        record.clientTier ? (
          <Tag aria-label={`VIP ${vipTierLabel(record.clientTier)}`}>
            {vipTierLabel(record.clientTier)}
          </Tag>
        ) : (
          "—"
        ),
    });
  }
  columns.push({
    title: "操作",
    key: "actions",
    fixed: "right",
    width: 108,
    render: (_, record) => {
      const pending = canReviewKyc(record.status);
      return (
        <Tooltip title={pending ? KYC_REVIEW_COPY.reviewAction : KYC_REVIEW_COPY.viewAction}>
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
        </Tooltip>
      );
    },
  });

  return (
    <Space orientation="vertical" size="middle" style={{ width: "100%" }} className="kyc-review-workspace">
      {error ? (
        <OpsErrorState title={error} onRetry={onRetry} />
      ) : null}

      <div className="ops-stat-strip" aria-label="KYC 状态统计">
        {(
          [
            ["ALL", "全部", counts.ALL],
            ["PENDING", "待审核", counts.PENDING],
            ["APPROVED", "已通过", counts.APPROVED],
            ["REJECTED", "已拒绝", counts.REJECTED],
          ] as const
        ).map(([value, label, count]) => (
          <button
            key={value}
            type="button"
            className="ops-stat-pill"
            aria-pressed={filter === value}
            aria-label={`筛选${label}`}
            onClick={() => setFilter(value)}
          >
            <span className="label">{label}</span>
            <span className="value">{count}</span>
          </button>
        ))}
      </div>

      <OpsToolbar
        extra={
          <Button
            icon={<ReloadOutlined aria-hidden />}
            loading={loading}
            aria-label="刷新 KYC 列表"
            onClick={onRetry}
          >
            刷新
          </Button>
        }
      >
        <Input
          allowClear
          prefix={<SearchOutlined aria-hidden />}
          aria-label="搜索已加载的客户标识或备注"
          placeholder="搜索已加载的姓名、客户标识或备注"
          value={keyword}
          onChange={(event) => setKeyword(event.target.value)}
          style={{ width: 320, maxWidth: "100%" }}
        />
        <Select
          aria-label="按 KYC 状态筛选"
          value={filter}
          style={{ width: 140 }}
          onChange={setFilter}
          options={[
            { label: "全部", value: "ALL" },
            { label: "待审核", value: "PENDING" },
            { label: "已通过", value: "APPROVED" },
            { label: "已拒绝", value: "REJECTED" },
          ]}
        />
        {hasFilters ? (
          <Button
            aria-label="清除 KYC 筛选"
            onClick={() => {
              setKeyword("");
              setFilter("ALL");
            }}
          >
            清除筛选
          </Button>
        ) : null}
      </OpsToolbar>
      <p className="ops-loaded-filter-caption">
        {LOADED_FILTER_CAPTION} {showReviewer ? "" : KYC_REVIEW_COPY.noReviewerOnList}
      </p>

      <Table<KycSubmissionView>
        rowKey="id"
        className="ops-directory-table"
        loading={loading}
        columns={columns}
        dataSource={visible}
        tableLayout="fixed"
        scroll={{ x: showReviewer ? 1680 : 1480 }}
        pagination={{
          ...OPS_TABLE_PAGINATION,
          showTotal: (total) => `共 ${total} 份提交`,
        }}
        locale={{
          emptyText: (
            <OpsEmpty
              description={
                loading
                  ? KYC_REVIEW_COPY.loading
                  : items.length
                    ? KYC_REVIEW_COPY.filteredEmpty
                    : KYC_REVIEW_COPY.empty
              }
              onRetry={hasFilters || loading ? undefined : onRetry}
            />
          ),
        }}
      />
    </Space>
  );
}
