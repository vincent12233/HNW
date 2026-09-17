#!/usr/bin/env python3
"""Refuse non-local / non-test Postgres URLs before prisma migrate deploy."""

from __future__ import annotations

import sys
from urllib.parse import unquote, urlparse

ALLOWED_HOSTS = {"localhost", "127.0.0.1", "postgres"}


def assert_safe_funding_integration_url(raw: str) -> tuple[str, str]:
    value = (raw or "").strip()
    if not value:
        raise SystemExit("FUNDING_INTEGRATION_DATABASE_URL is required")
    parsed = urlparse(value)
    if parsed.scheme not in {"postgres", "postgresql"}:
        raise SystemExit(
            "FUNDING_INTEGRATION_DATABASE_URL must use the postgres protocol"
        )
    host = (parsed.hostname or "").strip().lower()
    if host not in ALLOWED_HOSTS:
        raise SystemExit(
            f"Refusing host {parsed.hostname}. Allowed: localhost, 127.0.0.1, postgres"
        )
    database = unquote((parsed.path or "").lstrip("/").split("/")[0])
    lowered = database.lower()
    if not any(token in lowered for token in ("test", "e2e", "integration")):
        raise SystemExit(
            f'Refusing database "{database}". Name must contain test, e2e, or integration'
        )
    return host, database


if __name__ == "__main__":
    host, database = assert_safe_funding_integration_url(
        sys.argv[1] if len(sys.argv) > 1 else ""
    )
    print(f"Using isolated database {database} on {host}")
