# HNW Web/PWA operations

The customer Web client reuses the Flutter application and its protected API contracts. It does not implement a second registration, login, recovery, deposit, or trading path.

## Routing and privacy

- Publish the `client-web` container behind HTTPS and route customer traffic to port 8080.
- The browser uses same-origin `/api` and `/ws`; the container forwards those paths to the private API service.
- Authentication, KYC, support, account, funds, order, and trade requests are network-only and `no-store`. The service worker never queues or replays writes.
- Only the small public shell allowlist is cached. Financial responses, customer data, tokens, PINs, passwords, and uploaded evidence must never enter Cache Storage.

## Release and rollback

Build and deploy an immutable image for one Git SHA. Keep the previous image digest available. A rollback replaces only the Web image; it never reverses API migrations or committed financial facts. After promotion, verify `/`, a deep link, `/manifest.json`, `/pwa_service_worker.js`, `/api/health/ready`, WebSocket upgrade, login/logout, and one read-only market screen.

If an update is stuck, close all HNW tabs, remove the HNW site data/service worker in browser settings, and reopen the HTTPS origin. Support must not request passwords, PINs, recovery codes, or authenticator codes while troubleshooting.
