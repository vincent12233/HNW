"use client";

import { StopOutlined } from "@ant-design/icons";
import { Button, Result } from "antd";
import { useRouter } from "next/navigation";

import { homePathForRole } from "@/lib/ops-format";

type Props = {
  role?: string | null;
  description?: string;
};

export default function OpsPermissionDenied({
  role,
  description = "当前角色没有打开该页面的菜单权限。权限由服务端角色决定，本页不会扩大访问范围。",
}: Props) {
  const router = useRouter();
  const home = homePathForRole(role);

  return (
    <Result
      className="ops-permission-denied"
      status="403"
      icon={<StopOutlined aria-hidden />}
      title="没有访问该页面的权限"
      subTitle={description}
      extra={
        <Button
          type="primary"
          aria-label="返回工作台"
          onClick={() => router.replace(home)}
        >
          返回工作台
        </Button>
      }
    />
  );
}
