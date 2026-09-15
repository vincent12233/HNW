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
import { useEffect, useMemo, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api, getApiErrorMessage } from '@/lib/api';

const { Title, Paragraph, Text } = Typography;

type KycSubmission = {
  id: string;
  documentType: string;
  status: string;
  fileName: string;
  backFileName?: string | null;
  hasSelfie?: boolean;
  hasSignature?: boolean;
  recognizedType?: string | null;
  recognizedText?: string | null;
  reviewNote?: string | null;
  createdAt: string;
  userId: string;
  fullName: string;
  phone?: string | null;
  bankDetails?: { accountHolder: string; bankName: string; accountNumber: string; ifscCode: string };
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
  const [previewBackFile, setPreviewBackFile] = useState<KycFile | null>(null);
  const [note, setNote] = useState("");
  const [evidence, setEvidence] = useState<{
    selfie: KycFile | null;
    signature: KycFile | null;
  }>({ selfie: null, signature: null });
  const previewGeneration = useRef(0);
  const reviewLock = useRef(false);
  const [reviewSaving, setReviewSaving] = useState(false);

  const previewUrl = useMemo(() => {
    if (!previewFile) return "";
    return `data:${previewFile.mimeType};base64,${previewFile.contentBase64}`;
  }, [previewFile]);
  const previewBackUrl = useMemo(
    () =>
      previewBackFile
        ? `data:${previewBackFile.mimeType};base64,${previewBackFile.contentBase64}`
        : "",
    [previewBackFile],
  );

  async function loadItems() {
    setLoading(true);
    setError("");

    try {
      const response = await api.get<KycSubmission[]>("/kyc/business/pending");
      setItems(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      setError(responseMessage || "KYC 加载失败",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadItems();
  }, []);

  async function openReview(record: KycSubmission) {
    if (reviewLock.current) return;
    setReviewing(record);
    setPreviewFile(null);
    setPreviewBackFile(null);
    setEvidence({ selfie: null, signature: null });
    setNote(record.reviewNote || "");
    await loadFile(record.id);
  }

  async function loadFile(submissionId: string) {
    const generation = ++previewGeneration.current;
    setFileLoading(true);
    setError("");
    setPreviewFile(null);
    setPreviewBackFile(null);
    setEvidence({ selfie: null, signature: null });
    try {
      const record = items.find((item) => item.id === submissionId);
      const fetchSide = async (side: string) =>
        (
          await api.get<KycFile>(
            `/kyc/business/${submissionId}/file?side=${side}`,
          )
        ).data;
      // Load each evidence item independently. A missing optional side must
      // not hide the valid identity document or turn the whole review into a
      // generic “KYC failed to load” error.
      const results = await Promise.allSettled([
        fetchSide("front"),
        record?.backFileName ? fetchSide("back") : Promise.resolve(null),
        record?.hasSelfie ? fetchSide("selfie") : Promise.resolve(null),
        record?.hasSignature ? fetchSide("signature") : Promise.resolve(null),
      ]);
      const [frontResult, backResult, selfieResult, signatureResult] = results;
      const front = frontResult.status === "fulfilled" ? frontResult.value : null;
      const back = backResult.status === "fulfilled" ? backResult.value : null;
      const selfie = selfieResult.status === "fulfilled" ? selfieResult.value : null;
      const signature = signatureResult.status === "fulfilled" ? signatureResult.value : null;
      if (!front) {
        throw frontResult.status === "rejected" ? frontResult.reason : new Error("Front document is unavailable");
      }
      if (generation !== previewGeneration.current) return;
      setPreviewFile(front);
      setPreviewBackFile(back);
      setEvidence({ selfie, signature });
      const missing = [
        backResult.status === "rejected" ? "证件反面" : "",
        selfieResult.status === "rejected" ? "自拍" : "",
        signatureResult.status === "rejected" ? "签名" : "",
      ].filter(Boolean);
      if (missing.length) {
        setError(`部分资料暂时无法加载：${missing.join("、")}。证件正面仍可审核。`);
      }
    } catch (requestError: unknown) {
      if (generation !== previewGeneration.current) return;
      const responseMessage = getApiErrorMessage(requestError, "");
      setError(responseMessage || "审核资料加载失败，请重试",
      );
    } finally {
      if (generation === previewGeneration.current) setFileLoading(false);
    }
  }
  async function review(decision: "APPROVED" | "REJECTED") {
    if (!reviewing || fileLoading || !previewFile || reviewLock.current) return;
    reviewLock.current = true;
    setReviewSaving(true);

    try {
      await api.patch("/kyc/business/review", {
        submissionId: reviewing.id,
        decision,
        note,
      });
      message.success(decision === "APPROVED" ? "KYC 已通过" : "KYC 已拒绝");
      setReviewing(null);
      setPreviewFile(null);
      setPreviewBackFile(null);
      setEvidence({ selfie: null, signature: null });
      setNote("");
      await loadItems();
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      message.error(responseMessage || "KYC 审核失败，请刷新确认最新状态后重试",
      );
    } finally {
      reviewLock.current = false;
      setReviewSaving(false);
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
    {
      title: "文件",
      render: (_, record) =>
        record.backFileName ? "正面 + 反面" : record.fileName,
    },
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
            审核客户上传的 Aadhaar 或 PAN
            文件，系统会先根据文件名和选择类型做自动识别。
          </Paragraph>
        </div>

        {error && <Alert type="error" showIcon title={error} />}

        <Card>
          <Space style={{ marginBottom: 16 }}>
            <Button
              icon={<ReloadOutlined />}
              loading={loading}
              onClick={loadItems}
            >
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
          if (reviewLock.current) return;
          previewGeneration.current++;
          setReviewing(null);
          setPreviewFile(null);
          setPreviewBackFile(null);
          setEvidence({ selfie: null, signature: null });
          setNote("");
        }}
        footer={[
          <Button
            key="reject"
            disabled={fileLoading || !previewFile || reviewSaving}
            danger
            icon={<CloseOutlined />}
            onClick={() => review("REJECTED")}
          >
            拒绝
          </Button>,
          <Button
            key="approve"
            disabled={fileLoading || !previewFile || reviewSaving}
            loading={reviewSaving}
            type="primary"
            icon={<CheckOutlined />}
            onClick={() => review("APPROVED")}
          >
            通过
          </Button>,
        ]}
      >
        {reviewing && (
          <Space orientation="vertical" style={{ width: "100%" }} size="middle">
            <Space orientation="vertical" size={4}>
              <div>客户：{reviewing.fullName || "未命名客户"}</div>
              <div>手机号：{reviewing.phone?.startsWith('+') ? reviewing.phone : reviewing.phone ? `+91 ${reviewing.phone}` : '-'}</div>
              {reviewing.bankDetails && <div style={{ lineHeight: 1.8 }}>
                <div>银行：{reviewing.bankDetails.bankName}</div>
                <div>开户名：{reviewing.bankDetails.accountHolder}</div>
                <div>账号：{reviewing.bankDetails.accountNumber}</div>
                <div>IFSC：{reviewing.bankDetails.ifscCode || '未提供'}</div>
              </div>}
              <div>文件：{reviewing.fileName}</div>
              {reviewing.backFileName && (
                <div>反面：{reviewing.backFileName}</div>
              )}
              <div>证件类型：{reviewing.documentType || "-"}</div>
            </Space>

            <Card size="small" title="证件预览">
              {fileLoading && <Spin />}
              {!fileLoading && previewFile && (
                <Space orientation="vertical" style={{ width: "100%" }}>
                  <Button
                    icon={<DownloadOutlined />}
                    href={previewUrl}
                    download={previewFile.fileName}
                  >
                    下载文件
                  </Button>
                  {previewFile.mimeType.startsWith("image/") && (
                    <Image
                      src={previewUrl}
                      alt={previewFile.fileName}
                      style={{ maxHeight: 420, objectFit: "contain" }}
                    />
                  )}
                  {previewBackFile?.mimeType.startsWith("image/") && (
                    <>
                      <Text strong>Aadhaar 反面</Text>
                      <Button
                        icon={<DownloadOutlined />}
                        href={previewBackUrl}
                        download={previewBackFile.fileName}
                      >
                        下载反面
                      </Button>
                      <Image
                        src={previewBackUrl}
                        alt={previewBackFile.fileName}
                        style={{ maxHeight: 420, objectFit: "contain" }}
                      />
                    </>
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
                      <Alert
                        type="info"
                        showIcon
                        message="该文件类型无法预览，请下载后查看。"
                      />
                    )}
                </Space>
              )}
              {!fileLoading && !previewFile && (
                <Button
                  icon={<EyeOutlined />}
                  onClick={() => loadFile(reviewing.id)}
                >
                  查看文件
                </Button>
              )}
            </Card>

            {!fileLoading &&
              (
                [
                  ["selfie", "自拍"],
                  ["signature", "手写签名"],
                ] as const
              ).map(([key, label]) => {
                const file = evidence[key];
                return (
                  <Card key={key} size="small" title={label}>
                    {file ? (
                      <Image
                        src={`data:${file.mimeType};base64,${file.contentBase64}`}
                        alt={label}
                        style={{
                          maxHeight: 320,
                          objectFit: "contain",
                          background: "white",
                        }}
                      />
                    ) : (
                      <Text type="secondary">该历史申请未提交此项资料</Text>
                    )}
                  </Card>
                );
              })}

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
