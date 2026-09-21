"use client";

import {
  BellOutlined,
  BookOutlined,
  MobileOutlined,
  SettingOutlined,
  ShopOutlined,
  StarOutlined,
} from "@ant-design/icons";
import { Card, Col, Row, Space, Spin, Typography } from "antd";
import Link from "next/link";
import { useEffect, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsErrorState from "@/components/OpsErrorState";
import OpsPageHeader from "@/components/OpsPageHeader";
import { api, getApiErrorMessage } from "@/lib/api";

const { Text, Paragraph } = Typography;

type InsightArticle = { id: string; isPublished: boolean };
type Announcement = {
  id: string;
  isPublished: boolean;
  startsAt?: string | null;
  endsAt?: string | null;
};
type AppClientSetting = {
  platform: string;
  maintenanceMode: boolean;
  forceUpdate: boolean;
};
type InstrumentListResponse = { total: number };

function isAnnouncementLive(row: Announcement, now = Date.now()) {
  if (!row.isPublished) return false;
  if (row.startsAt && new Date(row.startsAt).getTime() > now) return false;
  if (row.endsAt && new Date(row.endsAt).getTime() < now) return false;
  return true;
}

const links = [
  {
    href: "/app-content",
    title: "文案配置",
    desc: "Home / Deposit / Support / Trading / Legal / About（KV）",
    icon: <SettingOutlined />,
  },
  {
    href: "/insights",
    title: "洞察文章",
    desc: "结构化 InsightArticle：发布、排序、预览",
    icon: <BookOutlined />,
  },
  {
    href: "/announcements",
    title: "平台公告",
    desc: "运营公告（≠ Market News / Banner）",
    icon: <BellOutlined />,
  },
  {
    href: "/featured-instruments",
    title: "精选标的",
    desc: "Home / Markets Featured（复用 Instrument）",
    icon: <StarOutlined />,
  },
  {
    href: "/app-settings",
    title: "客户端设置",
    desc: "版本门禁与维护模式（危险配置需确认）",
    icon: <MobileOutlined />,
  },
  {
    href: "/company-showcase",
    title: "平台公司信息",
    desc: "既有独立模块，不在此重复编辑",
    icon: <ShopOutlined />,
  },
];

export default function AppManagementHubPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [publishedInsights, setPublishedInsights] = useState(0);
  const [liveAnnouncements, setLiveAnnouncements] = useState(0);
  const [homeFeatured, setHomeFeatured] = useState(0);
  const [marketsFeatured, setMarketsFeatured] = useState(0);
  const [maintenancePlatforms, setMaintenancePlatforms] = useState<string[]>([]);

  async function load() {
    setLoading(true);
    setError("");
    try {
      const [insightsRes, announcementsRes, settingsRes, homeRes, marketsRes] =
        await Promise.all([
          api.get<InsightArticle[]>("/admin/insights"),
          api.get<Announcement[]>("/admin/announcements"),
          api.get<AppClientSetting[]>("/admin/app-settings"),
          api.get<InstrumentListResponse>("/admin/market/instruments", {
            params: { featuredHome: true, page: 1, pageSize: 1 },
          }),
          api.get<InstrumentListResponse>("/admin/market/instruments", {
            params: { featuredMarkets: true, page: 1, pageSize: 1 },
          }),
        ]);
      const insights = Array.isArray(insightsRes.data) ? insightsRes.data : [];
      const announcements = Array.isArray(announcementsRes.data)
        ? announcementsRes.data
        : [];
      const settings = Array.isArray(settingsRes.data) ? settingsRes.data : [];
      setPublishedInsights(insights.filter((r) => r.isPublished).length);
      setLiveAnnouncements(announcements.filter((r) => isAnnouncementLive(r)).length);
      setHomeFeatured(homeRes.data?.total ?? 0);
      setMarketsFeatured(marketsRes.data?.total ?? 0);
      setMaintenancePlatforms(
        settings.filter((s) => s.maintenanceMode).map((s) => s.platform),
      );
    } catch (e: unknown) {
      setError(getApiErrorMessage(e, "APP 管理总览加载失败"));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, []);

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <OpsPageHeader
          eyebrow="APP MANAGEMENT"
          title="APP 管理"
          description="超级管理员维护客户端运营内容。仅展示文案与运营配置，不改变交易、KYC、资金或行情逻辑。入口仅 ADMIN 可见。"
        />

        {error ? <OpsErrorState title={error} onRetry={() => void load()} /> : null}

        <Spin spinning={loading}>
          <div className="ops-stat-strip">
            <div className="ops-stat-pill">
              <span className="label">已发布 Insights</span>
              <span className="value">{publishedInsights}</span>
            </div>
            <div className="ops-stat-pill">
              <span className="label">生效中公告</span>
              <span className="value">{liveAnnouncements}</span>
            </div>
            <div className="ops-stat-pill">
              <span className="label">Home Featured</span>
              <span className="value">{homeFeatured}</span>
            </div>
            <div className="ops-stat-pill">
              <span className="label">Markets Featured</span>
              <span className="value">{marketsFeatured}</span>
            </div>
            <div className="ops-stat-pill">
              <span className="label">维护模式</span>
              <span className="value">
                {maintenancePlatforms.length
                  ? maintenancePlatforms.join(", ")
                  : "关闭"}
              </span>
            </div>
          </div>
        </Spin>

        <Row gutter={[16, 16]}>
          {links.map((item) => (
            <Col key={item.href} xs={24} sm={12} lg={8}>
              <Link href={item.href} style={{ display: "block" }}>
                <Card hoverable>
                  <Space orientation="vertical" size={8}>
                    <Space>
                      {item.icon}
                      <Text strong>{item.title}</Text>
                    </Space>
                    <Paragraph type="secondary" style={{ marginBottom: 0 }}>
                      {item.desc}
                    </Paragraph>
                  </Space>
                </Card>
              </Link>
            </Col>
          ))}
        </Row>
      </Space>
    </AdminShell>
  );
}
