#!/usr/bin/env node
/**
 * Writes frontend/web/env-config.js from environment variables.
 * Used by Vercel and local production builds so API URLs are not hard-coded.
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const target = process.argv[2]
  ? path.resolve(process.argv[2])
  : path.join(__dirname, '..', 'frontend', 'web', 'env-config.js');

const config = {
  apiBaseUrl: (process.env.API_BASE_URL || '').trim(),
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
}
