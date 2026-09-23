export const SESSION_TTL = {
  access: { jwt: '24h', seconds: 24 * 60 * 60 },
  refresh: { jwt: '30d', seconds: 30 * 24 * 60 * 60 },
} as const;
