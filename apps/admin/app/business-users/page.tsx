"use client";

import {
  GiftOutlined,
  LockOutlined,
  ProfileOutlined,
  ReloadOutlined,
  SearchOutlined,
  TeamOutlined,
} from "@ant-design/icons";
import {
  Button,
  Descriptions,
  Input,
  Popconfirm,
  Select,
  Space,
  Table,
  Tooltip,
  Typography,
  message,
} from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsDrawer from "@/components/OpsDrawer";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsModal from "@/components/OpsModal";
import OpsMoney from "@/components/OpsMoney";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import OpsToolbar from "@/components/OpsToolbar";
import { api, getApiErrorMessage } from "@/lib/api";
import {
  DIRECTORY_SCOPE_COPY,
  LOADED_FILTER_CAPTION,
  accountStatusLabel,
  filterLoadedRows,
  maskOpsPhone,
  useDebouncedValue,
} from "@/lib/ops-directory";
import { formatOpsDateTime, OPS_TABLE_PAGINATION } from "@/lib/ops-format";

const { Text } = Typography;

type BusinessUser = {
  id: string;
  userId: string;
  employeeNo: string;
  department?: string | null;
  isActive: boolean;
  createdAt: string;
  user: {
    id: string;
    fullName: string;
    phone?: string | null;
    role: string;
    status: string;
    createdAt: string;
    _count: {
      assignedCustomers: number;
    };
  };
  inviteCodes: Array<{ id: string }>;
  _count: {
    inviteCodes: number;
  };
};

type Customer = {
  id: string;
  customerNo?: string | null;
  fullName: string;
  phone?: string | null;
  status: string;
  createdAt: string;
  account?: {
    id: string;
    accountNumber: string;
    cashBalance: string | number;
    buyingPower: string | number;
    frozenBalance: string | number;
    currency: string;
  } | null;
  usedInviteCode?: {
    code: string;
    usedAt?: string | null;
  } | null;
};

export default function BusinessUsersPage() {
  const loadGen = useRef(0);
  const [records, setRecords] = useState<BusinessUser[]>([]);
  const [keyword, setKeyword] = useState("");
  const [statusFilter, setStatusFilter] = useState("ALL");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const debouncedKeyword = useDebouncedValue(keyword);

  const [customerOpen, setCustomerOpen] = useState(false);
  const [customerLoading, setCustomerLoading] = useState(false);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [detailOpen, setDetailOpen] = useState(false);
  const [selectedBusiness, setSelectedBusiness] = useState<BusinessUser | null>(null);
  const [passwordOpen, setPasswordOpen] = useState(false);
  const [newPassword, setNewPassword] = useState("");
  const [passwordLoading, setPasswordLoading] = useState(false);

  async function loadRecords() {
    const gen = ++loadGen.current;
    setLoading(true);
    setError("");
    try {
      const response = await api.get<BusinessUser[]>("/business");
      if (gen !== loadGen.current) return;
      setRecords(Array.isArray(response.data) ? response.data : [response.data]);
    } catch (requestError: unknown) {
      if (gen !== loadGen.current) return;
      setError(getApiErrorMessage(requestError, "业务员数据加载失败"));
      setRecords([]);
    } finally {
      if (gen === loadGen.current) setLoading(false);
    }
  }

  useEffect(() => {
    void loadRecords();
  }, []);

  const filteredRecords = useMemo(() => {
    return filterLoadedRows(
      records.filter((record) => {
        if (statusFilter === "ACTIVE") return record.isActive;
        if (statusFilter === "DISABLED") return !record.isActive;
        return true;
      }),
      debouncedKeyword,
      (record) => [
        record.employeeNo,
        record.user.fullName,
        record.user.phone,
        record.department,
      ],
    );
  }, [debouncedKeyword, records, statusFilter]);

  const hasFilters = keyword.trim() !== "" || statusFilter !== "ALL";

  async function openCustomers(record: BusinessUser) {
    setSelectedBusiness(record);
    setCustomerOpen(true);
    setCustomerLoading(true);
    setCustomers([]);
    try {
      const response = await api.get<Customer[]>(`/business/${record.userId}/customers`);
      setCustomers(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: unknown) {
      message.error(getApiErrorMessage(requestError, "客户数据加载失败"));
    } finally {
      setCustomerLoading(false);
    }
  }

  async function changeBusinessStatus(record: BusinessUser, isActive: boolean) {
    try {
      await api.patch(`/business/${record.userId}/status`, { isActive });
      message.success(isActive ? "业务员已启用" : "业务员已停用");
      await loadRecords();
    } catch (requestError: unknown) {
      message.error(getApiErrorMessage(requestError, "状态修改失败"));
    }
  }

  function openPasswordModal(record: BusinessUser) {
    setSelectedBusiness(record);
    setNewPassword("");
    setPasswordOpen(true);
  }

  async function resetPassword() {
    if (!selectedBusiness) return;
    if (newPassword.length < 12) {
      message.error("新密码至少需要 12 个字符");
      return;
    }
    setPasswordLoading(true);
    try {
      await api.patch(`/business/${selectedBusiness.userId}/reset-password`, {
        newPassword,
      });
      message.success("业务员密码已重置");
      setPasswordOpen(false);
      setNewPassword("");
    } catch (requestError: unknown) {
      message.error(getApiErrorMessage(requestError, "密码重置失败"));
    } finally {
      setPasswordLoading(false);
    }
  }

  const customerColumns: ColumnsType<Customer> = [
    {
      title: "客户编号",
      render: (_, record) => (
        <span className="ops-id">{record.customerNo || record.id}</span>
      ),
    },
    {
      title: "客户名称",
      dataIndex: "fullName",
      render: (value: string) => (
        <span className="ops-cell-clip" title={value}>
          {value}
        </span>
      ),
    },
    {
      title: "脱敏手机号",
      dataIndex: "phone",
      render: (value?: string | null) => maskOpsPhone(value),
    },
    {
      title: "状态",
      dataIndex: "status",
      render: (status: string) => (
        <OpsStatusTag code={status} label={accountStatusLabel(status)} />
      ),
    },
    {
      title: "交易账号",
      render: (_, record) => (
        <span className="ops-id">{record.account?.accountNumber || "—"}</span>
      ),
    },
    {
      title: "现金余额",
      align: "right",
      render: (_, record) => <OpsMoney value={record.account?.cashBalance} />,
    },
    {
      title: "创建时间",
      dataIndex: "createdAt",
      render: (value: string) => formatOpsDateTime(value),
    },
  ];

  const columns: ColumnsType<BusinessUser> = [
    {
      title: "员工号",
      dataIndex: "employeeNo",
      width: 130,
      fixed: "left",
      render: (value: string) => <span className="ops-id">{value}</span>,
    },
    {
      title: "姓名",
      width: 180,
      render: (_, record) => (
        <span className="ops-cell-clip" title={record.user.fullName}>
          {record.user.fullName}
        </span>
      ),
    },
    {
      title: "状态",
      width: 120,
      render: (_, record) => (
        <OpsStatusTag
          code={record.isActive ? "ACTIVE" : "DISABLED"}
          label={record.isActive ? "正常" : "已停用"}
        />
      ),
    },
    {
      title: "客户数量",
      width: 120,
      align: "right",
      render: (_, record) => record.user._count.assignedCustomers,
    },
    {
      title: "部门",
      dataIndex: "department",
      width: 140,
      render: (value) => value || "—",
    },
    {
      title: "可用邀请码",
      width: 120,
      align: "right",
      render: (_, record) => record.inviteCodes.length,
    },
    {
      title: "创建时间",
      dataIndex: "createdAt",
      width: 180,
      render: (value: string) => (
        <span className="ops-datetime">{formatOpsDateTime(value)}</span>
      ),
    },
    {
      title: "操作",
      key: "actions",
      width: 320,
      fixed: "right",
      render: (_, record) => (
        <Space wrap>
          <Button
            size="small"
            icon={<ProfileOutlined />}
            aria-label={`查看业务员 ${record.user.fullName} 详情`}
            onClick={() => {
              setSelectedBusiness(record);
              setDetailOpen(true);
            }}
          >
            详情
          </Button>
          <Tooltip title="查看名下客户">
            <Button
              size="small"
              icon={<TeamOutlined />}
              aria-label={`查看业务员 ${record.user.fullName} 名下客户`}
              onClick={() => openCustomers(record)}
            />
          </Tooltip>
          <Popconfirm
            title={record.isActive ? "确认停用业务员？" : "确认启用业务员？"}
            description={
              record.isActive
                ? "停用后将不能继续生成新的邀请码。"
                : "启用后可以继续生成邀请码。"
            }
            okText="确认"
            cancelText="取消"
            onConfirm={() => changeBusinessStatus(record, !record.isActive)}
          >
            <Button
              danger={record.isActive}
              size="small"
              className={record.isActive ? "ops-danger-action" : undefined}
              aria-label={record.isActive ? `停用 ${record.user.fullName}` : `启用 ${record.user.fullName}`}
            >
              {record.isActive ? "停用" : "启用"}
            </Button>
          </Popconfirm>
          <Tooltip title="重置密码">
            <Button
              size="small"
              icon={<LockOutlined />}
              aria-label={`重置业务员 ${record.user.fullName} 密码`}
              onClick={() => openPasswordModal(record)}
            />
          </Tooltip>
        </Space>
      ),
    },
  ];

  return (
    <AdminShell>
      <div className="ops-directory-panel">
        <OpsPageHeader
          title="业务员管理"
          crumbs={[{ title: "治理与人员" }, { title: "业务员管理" }]}
          description={DIRECTORY_SCOPE_COPY.businessUsers}
          extra={
            <Button
              icon={<ReloadOutlined />}
              aria-label="刷新业务员列表"
              onClick={() => void loadRecords()}
              loading={loading}
            >
              刷新
            </Button>
          }
        />
        {error ? <OpsErrorState title={error} onRetry={() => void loadRecords()} /> : null}
        <OpsToolbar
          extra={
            hasFilters ? (
              <Button
                aria-label="清除筛选"
                onClick={() => {
                  setKeyword("");
                  setStatusFilter("ALL");
                }}
              >
                清除筛选
              </Button>
            ) : null
          }
        >
          <Input
            allowClear
            prefix={<SearchOutlined />}
            placeholder="搜索已加载的员工号、姓名或部门"
            value={keyword}
            onChange={(event) => setKeyword(event.target.value)}
            aria-label="搜索已加载业务员"
            style={{ width: 320, maxWidth: "100%" }}
          />
          <Select
            aria-label="按状态筛选已加载结果"
            value={statusFilter}
            style={{ width: 140 }}
            onChange={setStatusFilter}
            options={[
              { value: "ALL", label: "全部状态" },
              { value: "ACTIVE", label: "正常" },
              { value: "DISABLED", label: "已停用" },
            ]}
          />
        </OpsToolbar>
        <p className="ops-loaded-filter-caption">{LOADED_FILTER_CAPTION}</p>
        <Table<BusinessUser>
          rowKey="id"
          className="ops-directory-table"
          columns={columns}
          dataSource={filteredRecords}
          loading={loading}
          tableLayout="fixed"
          scroll={{ x: 1480 }}
          pagination={{
            ...OPS_TABLE_PAGINATION,
            showTotal: (total) => `共 ${total} 位业务员`,
          }}
          locale={{
            emptyText: (
              <OpsEmpty
                description={hasFilters ? "没有匹配的已加载结果" : "暂无业务员记录"}
                onRetry={hasFilters ? undefined : () => void loadRecords()}
              />
            ),
          }}
        />
      </div>

      <OpsDrawer
        title={selectedBusiness ? `${selectedBusiness.user.fullName} · 业务员详情` : "业务员详情"}
        open={detailOpen}
        onClose={() => setDetailOpen(false)}
        width={480}
      >
        {selectedBusiness ? (
          <Descriptions size="small" column={1} bordered>
            <Descriptions.Item label="员工号">
              <span className="ops-id">{selectedBusiness.employeeNo}</span>
            </Descriptions.Item>
            <Descriptions.Item label="姓名">
              {selectedBusiness.user.fullName}
            </Descriptions.Item>
            <Descriptions.Item label="状态">
              <OpsStatusTag
                code={selectedBusiness.isActive ? "ACTIVE" : "DISABLED"}
                label={selectedBusiness.isActive ? "正常" : "已停用"}
              />
            </Descriptions.Item>
            <Descriptions.Item label="客户数量">
              {selectedBusiness.user._count.assignedCustomers}
            </Descriptions.Item>
            <Descriptions.Item label="可用邀请码">
              <Space>
                <GiftOutlined aria-hidden />
                {selectedBusiness.inviteCodes.length}
              </Space>
            </Descriptions.Item>
            <Descriptions.Item label="创建时间">
              {formatOpsDateTime(selectedBusiness.createdAt)}
            </Descriptions.Item>
            <Descriptions.Item label="所属管理员">
              当前接口未返回所属管理员，不在前端推算。
            </Descriptions.Item>
          </Descriptions>
        ) : null}
      </OpsDrawer>

      <OpsDrawer
        title={selectedBusiness ? `${selectedBusiness.user.fullName} · 名下客户` : "名下客户"}
        open={customerOpen}
        onClose={() => setCustomerOpen(false)}
        width={720}
      >
        <Table<Customer>
          rowKey="id"
          columns={customerColumns}
          dataSource={customers}
          loading={customerLoading}
          scroll={{ x: 980 }}
          pagination={OPS_TABLE_PAGINATION}
          locale={{ emptyText: <OpsEmpty description="该业务员名下暂无客户" /> }}
        />
      </OpsDrawer>

      <OpsModal
        title="重置业务员密码"
        open={passwordOpen}
        onCancel={() => setPasswordOpen(false)}
        onOk={resetPassword}
        confirmLoading={passwordLoading}
        okText="重置密码"
        cancelText="取消"
      >
        <Space orientation="vertical" style={{ width: "100%" }}>
          <Text>业务员：{selectedBusiness?.user.fullName || "—"}</Text>
          <Input.Password
            value={newPassword}
            onChange={(event) => setNewPassword(event.target.value)}
            placeholder="请输入至少 12 个字符的新密码"
            prefix={<LockOutlined />}
            aria-label="新密码"
          />
        </Space>
      </OpsModal>
    </AdminShell>
  );
}
