"use client";

import { App, ConfigProvider } from "antd";
import zhCN from "antd/locale/zh_CN";
import { ReactNode } from "react";

export default function AppProviders({ children }: { children: ReactNode }) {
  return (
    <ConfigProvider
      locale={zhCN}
      theme={{
        token: {
          colorPrimary: "#1677ff",
          colorInfo: "#1677ff",
          borderRadius: 10,
          fontFamily:
            '"DM Sans", "Noto Sans SC", "PingFang SC", "Microsoft YaHei", sans-serif',
          controlHeight: 36,
        },
        components: {
          Layout: {
            headerBg: "transparent",
            bodyBg: "transparent",
            siderBg: "transparent",
          },
          Menu: {
            darkItemBg: "transparent",
            darkSubMenuItemBg: "transparent",
            itemBorderRadius: 10,
          },
          Card: {
            borderRadiusLG: 14,
          },
          Table: {
            headerBorderRadius: 10,
          },
          Button: {
            borderRadius: 10,
          },
        },
      }}
    >
      <App>{children}</App>
    </ConfigProvider>
  );
}
