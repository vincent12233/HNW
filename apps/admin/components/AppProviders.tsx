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
          borderRadius: 8,
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
            itemBorderRadius: 8,
          },
          Card: {
            borderRadiusLG: 8,
          },
          Table: {
            headerBorderRadius: 8,
          },
          Button: {
            borderRadius: 8,
          },
          Drawer: {
            paddingLG: 16,
          },
          Modal: {
            borderRadiusLG: 8,
          },
        },
      }}
    >
      <App>{children}</App>
    </ConfigProvider>
  );
}
