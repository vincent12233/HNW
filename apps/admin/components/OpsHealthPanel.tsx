"use client";

import { ReloadOutlined } from "@ant-design/icons";
import { Button, Skeleton, Space, Typography } from "antd";
import { useCallback, useEffect, useRef, useState } from "react";

import OpsErrorState from "@/components/OpsErrorState";
import OpsStatusTag from "@/components/OpsStatusTag";
import { api } from "@/lib/api";
import { formatOpsDateTime } from "@/lib/ops-format";
import {
  GOVERNANCE_COPY,
  UNAVAILABLE,
  healthCodeFromProbe,
  type HealthCode,
} from "@/lib/ops-governance";

const { Text } = Typography;

type ProbeCard = {
  id: string;
  title: string;
  code: HealthCode;
  updatedAt: string | null;
  detail: string;
};

type LiveHealth = { status?: string; timestamp?: string };
type ReadyHealth = { status?: string; database?: string; timestamp?: string };
type MarketHealth = {
  healthy?: boolean;
  stale?: boolean;
  lastQuoteAt?: string | null;
  lastSource?: string | null;
  ageMs?: number | null;
  streaming?: { enabled?: boolean; provider?: string; connected?: boolean };
};
type SessionHealth = { status?: string; phase?: string; asOf?: string; timestamp?: string };

function cardFromSettled<T>(
  id: string,
  title: string,
  settled: PromiseSettledResult<T>,
  read: (value: T) => ProbeCard,
): ProbeCard {
  if (settled.status !== "fulfilled") {
    return { id, title, code: "UNAVAILABLE", updatedAt: null, detail: UNAVAILABLE };
  }
  return read(settled.value);
}

export default function OpsHealthPanel() {
  const [cards, setCards] = useState<ProbeCard[]>([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const inflight = useRef(false);

  const load = useCallback(async () => {
    if (inflight.current) return;
    inflight.current = true;
    setLoading(true);
    setError("");
    try {
      const [live, ready, market, session] = await Promise.allSettled([
        api.get<LiveHealth>("/health"),
        api.get<ReadyHealth>("/health/ready"),
        api.get<MarketHealth>("/market-data/health"),
        api.get<SessionHealth>("/market-data/session"),
      ]);

      setCards([
        cardFromSettled("live", "API 存活", live, (result) => ({
          id: "live",
          title: "API 存活",
          code: healthCodeFromProbe({ status: result.data.status }),
          updatedAt: result.data.timestamp ?? null,
          detail: result.data.status || UNAVAILABLE,
        })),
        cardFromSettled("ready", "数据库就绪", ready, (result) => ({
          id: "ready",
          title: "数据库就绪",
          code: healthCodeFromProbe({ status: result.data.status }),
          updatedAt: result.data.timestamp ?? null,
          detail: result.data.database || result.data.status || UNAVAILABLE,
        })),
        cardFromSettled("market", "行情源", market, (result) => ({
          id: "market",
          title: "行情源",
          code: healthCodeFromProbe({
            healthy: result.data.healthy,
            stale: result.data.stale,
          }),
          updatedAt: result.data.lastQuoteAt ?? null,
          detail: [
            result.data.lastSource || UNAVAILABLE,
            result.data.streaming?.enabled
              ? `stream ${result.data.streaming.provider || UNAVAILABLE}`
              : "stream off",
          ].join(" · "),
        })),
        cardFromSettled("session", "交易时段", session, (result) => ({
          id: "session",
          title: "交易时段",
          code: "UNKNOWN",
          updatedAt: result.data.asOf ?? result.data.timestamp ?? null,
          detail: result.data.status || result.data.phase || UNAVAILABLE,
        })),
      ]);
    } catch {
      setError("健康检查刷新失败。未使用缓存状态。");
    } finally {
      inflight.current = false;
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
    return () => {
      inflight.current = false;
    };
  }, [load]);

  return (
    <section className="ops-health-panel" aria-label="系统健康">
      <div className="ops-health-head">
        <Text type="secondary">{GOVERNANCE_COPY.healthHonest}</Text>
        <Button
          icon={<ReloadOutlined />}
          loading={loading}
          onClick={() => void load()}
          aria-label="刷新系统健康"
        >
          刷新健康状态
        </Button>
      </div>
      {error ? <OpsErrorState title={error} onRetry={() => void load()} /> : null}
      <div className="ops-health-grid">
        {loading && !cards.length
          ? ["live", "ready", "market", "session"].map((id) => (
              <article key={id} className="ops-health-card" aria-busy="true">
                <Skeleton active title={{ width: "40%" }} paragraph={{ rows: 2 }} />
              </article>
            ))
          : cards.map((card) => (
              <article key={card.id} className="ops-health-card">
                <Space orientation="vertical" size={6}>
                  <Text type="secondary">{card.title}</Text>
                  <OpsStatusTag code={card.code} />
                  <Text className="ops-wrap-text">{card.detail || UNAVAILABLE}</Text>
                  <Text type="secondary">{formatOpsDateTime(card.updatedAt)}</Text>
                </Space>
              </article>
            ))}
      </div>
    </section>
  );
}
