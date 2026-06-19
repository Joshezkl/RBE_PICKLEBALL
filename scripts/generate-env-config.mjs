#!/usr/bin/env node
/**
 * Writes frontend/web/env-config.js from environment variables.
 * On Vercel, defaults API_BASE_URL to the same deployment origin (/api).
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const target = process.argv[2]
  ? path.resolve(process.argv[2])
  : path.join(__dirname, '..', 'frontend', 'web', 'env-config.js');

function defaultApiBaseUrl() {
  if (process.env.API_BASE_URL?.trim()) {
    return process.env.API_BASE_URL.trim();
  }

  const host =
    process.env.VERCEL_PROJECT_PRODUCTION_URL?.trim() ||
    process.env.VERCEL_URL?.trim() ||
    '';

  if (host) {
    return `https://${host}/api`;
  }

  return '';
}

const config = {
  apiBaseUrl: defaultApiBaseUrl(),
  wsHost: (process.env.WS_HOST || '').trim(),
  wsScheme: (process.env.WS_SCHEME || '').trim(),
  wsKey: (process.env.WS_KEY || '').trim(),
};

const content = `// Generated at build time — do not edit manually.
window.__RBE_CONFIG__ = ${JSON.stringify(config, null, 2)};
`;

fs.mkdirSync(path.dirname(target), { recursive: true });
fs.writeFileSync(target, content, 'utf8');

console.log(`Wrote runtime config to ${target}`);
if (config.apiBaseUrl) {
  console.log(`  API_BASE_URL=${config.apiBaseUrl}`);
} else {
  console.log('  API_BASE_URL=(empty — local dev will use localhost fallback)');
}
