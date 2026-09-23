import type { NextConfig } from "next";

const isDev = process.env.NODE_ENV === "development";
const devScriptPolicy = isDev ? " 'unsafe-eval'" : "";

function resolveConnectSrc() {
  const apiUrl = process.env.NEXT_PUBLIC_API_URL?.trim();
  if (isDev) {
    const localApiOrigin = (() => {
      try {
        return apiUrl ? new URL(apiUrl).origin : 'http://localhost:3000';
      } catch {
        return 'http://localhost:3000';
      }
    })();
    return `'self' https: ${localApiOrigin}`;
  }
  if (apiUrl?.startsWith("https://")) {
    try {
      return `'self' ${new URL(apiUrl).origin}`;
    } catch {
      // Fall through to HTTPS-any if the URL is malformed at build time.
    }
  }
  // CI / unset API URL: still block cleartext; pin when NEXT_PUBLIC_API_URL is set.
  return "'self' https:";
}

const connectSrc = resolveConnectSrc();
const strictTransportSecurity = isDev
  ? []
  : [{ key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains; preload" }];

const nextConfig: NextConfig = {
  distDir: process.env.NEXT_DIST_DIR || '.next',
  allowedDevOrigins: ['127.0.0.2', '127.0.0.3', '127.0.0.4', '127.0.0.5'],
  devIndicators: false,
  poweredByHeader: false,
  async headers() {
    return [{ source: "/(.*)", headers: [
      { key: "Content-Security-Policy", value: `default-src 'self'; script-src 'self' 'unsafe-inline'${devScriptPolicy}; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src ${connectSrc}; frame-src 'self' data: blob:; frame-ancestors 'none'; object-src 'none'; base-uri 'self'; form-action 'self'` },
      { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
      { key: "X-Content-Type-Options", value: "nosniff" },
      { key: "X-Frame-Options", value: "DENY" },
      { key: "Cross-Origin-Opener-Policy", value: "same-origin" },
      { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
      ...strictTransportSecurity,
    ] }];
  },
};

export default nextConfig;
