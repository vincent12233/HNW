import type { NextConfig } from "next";

const isDev = process.env.NODE_ENV === "development";
const devScriptPolicy = isDev ? " 'unsafe-eval'" : "";
// Local API hosts only in development; production connect-src is self + HTTPS.
const connectSrc = isDev
  ? "'self' https: http://localhost:3000 http://127.0.0.1:3000"
  : "'self' https:";

const nextConfig: NextConfig = {
  distDir: process.env.NEXT_DIST_DIR || '.next',
  allowedDevOrigins: ['127.0.0.2', '127.0.0.3', '127.0.0.4', '127.0.0.5'],
  devIndicators: false,
  poweredByHeader: false,
  async headers() {
    return [{ source: "/(.*)", headers: [
      { key: "Content-Security-Policy", value: `default-src 'self'; script-src 'self' 'unsafe-inline'${devScriptPolicy}; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src ${connectSrc}; frame-ancestors 'none'; base-uri 'self'; form-action 'self'` },
      { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
      { key: "X-Content-Type-Options", value: "nosniff" },
      { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
    ] }];
  },
};

export default nextConfig;
