# HNW edge gateway

The optional Envoy profile provides bounded HTTP/WebSocket routing. It removes
untrusted forwarding headers, limits request bodies, and routes `/api`,
`/socket.io`, and `/ws` to the API. The API remains the authorization boundary.

Terminate TLS at the managed ingress. Never expose the Envoy admin listener;
it binds to container loopback only.
