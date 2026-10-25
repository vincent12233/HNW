CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE TABLE IF NOT EXISTS market_ticks (
  instrument_id TEXT NOT NULL,
  exchange TEXT NOT NULL,
  symbol TEXT NOT NULL,
  sequence BIGINT NOT NULL,
  price NUMERIC(18,4) NOT NULL,
  volume BIGINT NOT NULL DEFAULT 0,
  source_timestamp TIMESTAMPTZ NOT NULL,
  received_at TIMESTAMPTZ NOT NULL,
  quality TEXT NOT NULL CHECK (quality IN ('LIVE', 'DELAYED', 'STALE', 'UNAVAILABLE')),
  PRIMARY KEY (instrument_id, sequence, source_timestamp)
);

SELECT create_hypertable('market_ticks', 'source_timestamp', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS market_ticks_instrument_time_idx ON market_ticks (instrument_id, source_timestamp DESC);
ALTER TABLE market_ticks SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'instrument_id',
  timescaledb.compress_orderby = 'source_timestamp DESC'
);
SELECT add_compression_policy('market_ticks', INTERVAL '7 days', if_not_exists => TRUE);
SELECT add_retention_policy('market_ticks', INTERVAL '2 years', if_not_exists => TRUE);
