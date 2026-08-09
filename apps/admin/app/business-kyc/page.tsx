"use client";

import {
  CheckOutlined,
  CloseOutlined,
  DownloadOutlined,
  EyeOutlined,
  ReloadOutlined,
  SafetyCertificateOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Image,
  Input,
  Modal,
  Space,
  Spin,
  Table,
  Tag,
  Typography,
  message,
} from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;

type KycSubmission = {
  id: string;
  documentType: string;
  status: string;
  fileName: string;
  recognizedType?: string | null;
  recognizedText?: string | null;
  reviewNote?: string | null;
  createdAt: string;
  userId: string;
  fullName: string;
  phone?: string | null;
};

type KycFile = {
  fileName: string;
  mimeType: string;
  contentBase64: string;
};

function statusTag(status: string) {
  if (status === "APPROVED") return <Tag color="green">已通过</Tag>;
  if (status === "REJECTED") return <Tag color="red">已拒绝</Tag>;
  return <Tag color="orange">待审核</Tag>;
}

function formatDate(value?: string | null) {
  return value ? new Date(value).toLocaleString("zh-CN") : "-";
}

export default function BusinessKycPage() {
  const [items, setItems] = useState<KycSubmission[]>([]);
  const [loading, setLoading] = useState(false);
  const [fileLoading, setFileLoading] = useState(false);
  const [error, setError] = useState("");
  const [reviewing, setReviewing] = useState<KycSubmission | null>(null);
  const [previewFile, setPreviewFile] = useState<KycFile | null>(null);
  const [note, setNote] = useState("");

  const previewUrl = useMemo(() => {
    if (!previewFile) return "";
    return `data:${previewFile.mimeType};base64,${previewFile.contentBase64}`;
  }, [previewFile]);

  async function loadItems() {
    setLoading(true);
    setError("");

    try {
      const response = await api.get<KycSubmission[]>("/kyc/business/pending");
      setItems(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: any) {
      const responseMessage = requestError.response?.data?.message;
      setError(
        Array.isArray(responseMessage)
          ? responseMessage.join("，")
          : responseMessage || "KYC 加载失败",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadItems();
  }, []);

  async function openReview(record: KycSubmission) {
    setReviewing(record);
    setPreviewFile(null);
    setNote(record.reviewNote || "");
    await loadFile(record.id);
  }

  async function loadFile(submissionId: string) {
    setFileLoading(true);
    setError("");

    try {
      const response = await api.get<KycFile>(`/kyc/business/${submissionId}/file`);
      setPreviewFile(response.data);
    } catch (requestError: any) {
      const responseMessage = requestError.response?.data?.message;
      setError(
        Array.isArray(responseMessage)
          ? responseMessage.join("，")
          : responseMessage || "证件文件加载失败",
      );
    } finally {
      setFileLoading(false);
    }
  }

  async function review(decision: "APPROVED" | "REJECTED") {
    if (!reviewing) return;

    try {
      await api.patch("/kyc/business/review", {
        submissionId: reviewing.id,
        decision,
        note,
      });
      message.success(decision === "APPROVED" ? "KYC 已通过" : "KYC 已拒绝");
      setReviewing(null);
      setPreviewFile(null);
      setNote("");
      await loadItems();
    } catch (requestError: any) {
      const responseMessage = requestError.response?.data?.message;
      message.error(
        Array.isArray(responseMessage)
          ? responseMessage.join("，")
          : responseMessage || "KYC 审核失败",
      );
    }
  }

  const columns: ColumnsType<KycSubmission> = [
    {
      title: "客户",
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{record.fullName || "未命名客户"}</Text>
          <Text type="secondary">+91 {record.phone || "-"}</Text>
        </Space>
      ),
    },
    {
      title: "提交类型",
      dataIndex: "documentType",
      render: (value) => <Tag>{value}</Tag>,
    },
    {
      title: "自动识别",
      dataIndex: "recognizedType",
      render: (value) => <Tag color="blue">{value || "-"}</Tag>,
    },
    { title: "文件", dataIndex: "fileName" },
    { title: "状态", dataIndex: "status", render: statusTag },
    { title: "提交时间", dataIndex: "createdAt", render: formatDate },
    {
      title: "操作",
      render: (_, record) => (
        <Button
          type="primary"
          size="small"
          icon={<SafetyCertificateOutlined />}
          onClick={() => openReview(record)}
          disabled={record.status !== "PENDING"}
        >
          审核
        </Button>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>KYC 审核</Title>
          <Paragraph type="secondary">
            审核客户上传的 Aadhaar 或 PAN 文件，系统会先根据文件名和选择类型做自动识别。
          </Paragraph>
        </div>

        {error && <Alert type="error" showIcon title={error} />}

        <Card>
          <Space style={{ marginBottom: 16 }}>
            <Button icon={<ReloadOutlined />} loading={loading} onClick={loadItems}>
              刷新
            </Button>
          </Space>

          <Table<KycSubmission>
            rowKey="id"
            loading={loading}
            columns={columns}
            dataSource={items}
          />
        </Card>
      </Space>

      <Modal
        title="审核 KYC"
        open={!!reviewing}
        width={860}
        onCancel={() => {
          setReviewing(null);
          setPreviewFile(null);
          setNote("");
        }}
        footer={[
          <Button key="reject" danger icon={<CloseOutlined />} onClick={() => review("REJECTED")}>
            拒绝
          </Button>,
          <Button key="approve" type="primary" icon={<CheckOutlined />} onClick={() => review("APPROVED")}>
            通过
          </Button>,
        ]}
      >
        {reviewing && (
          <Space orientation="vertical" style={{ width: "100%" }} size="middle">
            <Space orientation="vertical" size={4}>
              <div>客户：{reviewing.fullName || "未命名客户"}</div>
              <div>手机号：+91 {reviewing.phone || "-"}</div>
              <div>文件：{reviewing.fileName}</div>
              <div>自动识别：{reviewing.recognizedType || "-"}</div>
            </Space>

            <Card size="small" title="证件预览">
              {fileLoading && <Spin />}
              {!fileLoading && previewFile && (
                <Space orientation="vertical" style={{ width: "100%" }}>
                  <Button icon={<DownloadOutlined />} href={previewUrl} download={previewFile.fileName}>
                    下载文件
                  </Button>
                  {previewFile.mimeType.startsWith("image/") && (
                    <Image
                      src={previewUrl}
                      alt={previewFile.fileName}
                      style={{ maxHeight: 420, objectFit: "contain" }}
                    />
                  )}
                  {previewFile.mimeType === "application/pdf" && (
                    <iframe
                      title={previewFile.fileName}
                      src={previewUrl}
                      style={{
                        width: "100%",
                        height: 520,
                        border: "1px solid #f0f0f0",
                        borderRadius: 6,
                      }}
                    />
                  )}
                  {!previewFile.mimeType.startsWith("image/") &&
                    previewFile.mimeType !== "application/pdf" && (
                      <Alert type="info" showIcon message="该文件类型无法预览，请下载后查看。" />
                    )}
                </Space>
              )}
              {!fileLoading && !previewFile && (
                <Button icon={<EyeOutlined />} onClick={() => loadFile(reviewing.id)}>
                  查看文件
                </Button>
              )}
            </Card>

            <Input.TextArea
              rows={4}
              placeholder="审核备注"
              value={note}
              onChange={(event) => setNote(event.target.value)}
            />
          </Space>
        )}
      </Modal>
    </AdminShell>
  );
}
