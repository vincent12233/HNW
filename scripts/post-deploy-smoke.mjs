const apiUrl = (process.env.PRODUCTION_API_URL ?? process.argv[2] ?? '').replace(/\/$/, '');
const adminUrls = (process.env.PRODUCTION_ADMIN_URLS ?? process.argv[3] ?? '')
  .split(',').map((value) => value.trim().replace(/\/$/, '')).filter(Boolean);
const attempts = Number(process.env.SMOKE_ATTEMPTS ?? 30);
const delayMs = Number(process.env.SMOKE_DELAY_MS ?? 10000);

if (!apiUrl || !adminUrls.length) {
  console.error('Set PRODUCTION_API_URL and comma-separated PRODUCTION_ADMIN_URLS');
  process.exit(2);
}
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const fetchOk = async (url) => {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await fetch(url, { signal: controller.signal, redirect: 'follow' });
    return response.ok;
  } catch {
    return false;
  } finally {
    clearTimeout(timer);
  }
};

for (let attempt = 1; attempt <= attempts; attempt += 1) {
  const ready = await fetchOk(`${apiUrl}/health/ready`);
  const adminResults = await Promise.all(adminUrls.map((url) => fetchOk(`${url}/login`)));
  if (ready && adminResults.every(Boolean)) {
    console.log(`Production smoke check passed on attempt ${attempt}`);
    process.exit(0);
  }
  if (attempt < attempts) await wait(delayMs);
}
console.error('Production smoke check failed; use the Coolify deployment logs and roll back to the previous successful deployment.');
process.exit(1);
