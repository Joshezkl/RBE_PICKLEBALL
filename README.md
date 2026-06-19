# Rosales Pickleball Club — Queue & Court Management System

Digital queue and court management for open-play pickleball sessions. Features dual Winner/Loser queues, alternating court assignment, partner-rotation pairing, admin dashboard, public board view, and end-of-session reporting.

## Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter Web |
| Backend | Laravel 12 REST API |
| Database | MySQL (SQLite supported for local testing) |
| Real-time | Laravel Broadcasting (Reverb optional) + polling fallback |

## Project Structure

```
RBE/
├── api/         # Vercel serverless entry for Laravel (/api/*)
├── backend/     # Laravel API
├── frontend/    # Flutter web app (Admin + Board views)
├── scripts/     # Vercel build helpers
├── vercel.json  # Vercel deployment (frontend + API)
└── README.md
```

## Prerequisites

- PHP 8.2+
- Composer
- MySQL (XAMPP) or SQLite
- Flutter 3.7+
- Node.js (optional, for Laravel Vite assets)

## Backend Setup

```bash
cd backend
cp .env.example .env
php artisan key:generate
```

### MySQL (recommended)

1. Create database `rpc_queue` in phpMyAdmin or MySQL CLI.
2. Update `backend/.env`:

```
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=rpc_queue
DB_USERNAME=root
DB_PASSWORD=

ADMIN_PIN=1234
```

3. Run migrations:

```bash
php artisan migrate
```

### SQLite (quick local test)

```
DB_CONNECTION=sqlite
```

Then run `php artisan migrate`.

### Start API server

```bash
php artisan serve
```

API base URL: **http://localhost:8000/api**

Default admin PIN: **1234** (set `ADMIN_PIN` in `.env`)

## Frontend Setup

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api
```

### Routes

| URL | Purpose |
|-----|---------|
| `/admin` | Queue Master — full session control |
| Players modal (admin app bar) | Register, search, join/remove session players |
| `/admin/leaderboard` | Session leaderboard (current or historical session) |
| `/leaderboard` | All-time club rankings (public / board view) |
| `/admin/calendar` | Session history calendar |
| `/board` | Public read-only display for courts and queues |
| `/check-in?token=…` | Player self check-in (scan QR — no admin PIN) |

## API Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/api/health` | No | Health check |
| GET | `/api/sessions/calendar` | PIN | Session counts by day (`year`, `month`) |
| GET | `/api/sessions/history` | PIN | Sessions on a date (`date=YYYY-MM-DD`) |
| GET | `/api/sessions/{id}/history` | PIN | Full session history detail |
| GET | `/api/sessions/active` | No | Active session state |
| GET | `/api/sessions/{id}/state` | No | Full live state |
| POST | `/api/sessions` | PIN | Start session (`match_mode`, `play_format`, `court_count`) |
| POST | `/api/sessions/{id}/end` | PIN | End session + report |
| GET | `/api/sessions/{id}/report` | PIN | Session report |
| GET | `/api/players` | PIN | List club players (`?search=`) |
| POST | `/api/players` | PIN | Register persistent club player |
| DELETE | `/api/players/{id}` | PIN | Delete club player permanently |
| POST | `/api/session/join` | PIN | Join club player to active session |
| POST | `/api/session/remove` | PIN | Remove player from active session |
| GET | `/api/leaderboard/all-time` | No | All-time club leaderboard (public, min. 3 matches) |
| GET | `/api/leaderboard/session/{id}` | No | Per-session leaderboard (that session only) |
| GET | `/api/check-in/session` | Check-in token | Session info for kiosk |
| GET | `/api/check-in/players` | Check-in token | Search players (`?search=`) |
| POST | `/api/check-in/register` | Check-in token | Register + join session |
| POST | `/api/check-in/join` | Check-in token | Join session as existing player |
| GET | `/api/check-in/status` | Check-in token | Queue/court status (`club_player_id`) |

Check-in token header: `X-Check-In-Token` (also accepted as `?token=` query param). Token is generated per session and shown in the admin QR panel.
| POST | `/api/sessions/{id}/players` | PIN | Add player to session roster (links club player) |
| DELETE | `/api/sessions/{id}/players/{id}` | PIN | Remove player from session roster |
| POST | `/api/sessions/{id}/matches/{id}/score` | PIN | Enter score |
| POST | `/api/sessions/{id}/courts/{id}/assign` | PIN | Manual court assign |

Admin PIN header: `X-Admin-Pin`

## Match Flow

1. Admin chooses a **match mode** (Auto-Balanced default) and starts a session. Courts begin empty.
2. Admin registers players — they alternate into Winners/Losers queues **two at a time**.
3. Admin manually assigns players to each available court.
4. Admin enters scores when matches finish.
5. Winners → Winners queue, Losers → Losers queue; courts stay empty until manually assigned again.
6. Former partners stay together once, then face each other on next grouping.
7. Admin ends session → report with matches, utilization, and player W/L.

## Real-time Updates

- **Polling:** Flutter polls session state every 3 seconds (always active).
- **WebSocket (optional):** Install Laravel Reverb for instant updates.

```bash
cd backend
composer require laravel/reverb
php artisan reverb:install
php artisan reverb:start
```

Set in `.env`:

```
BROADCAST_CONNECTION=reverb
REVERB_APP_ID=rpc-app
REVERB_APP_KEY=rpc-key
REVERB_APP_SECRET=rpc-secret
REVERB_HOST=localhost
REVERB_PORT=8080
```

Run Flutter with:

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000/api \
  --dart-define=WS_HOST=localhost:8080 \
  --dart-define=WS_SCHEME=ws \
  --dart-define=WS_KEY=rpc-key
```

Production (HTTPS) uses `wss` automatically when `API_BASE_URL` is `https://…`, or set `WS_SCHEME=wss` explicitly.

## Vercel Deployment (Frontend + API)

Everything runs on **one Vercel project**: Flutter web at `/` and the Laravel API at `/api/*` on the same public URL (e.g. `https://rbe-pickleball.vercel.app`).

### Architecture

```
https://your-app.vercel.app
├── /#/admin, /#/board, …   → Flutter web (static)
└── /api/*                  → Laravel (Vercel serverless PHP)
```

No separate API host is required. The app calls `/api` on the same domain — no CORS issues, no Railway or third-party API URL.

### 1. Import to Vercel

1. Import `RBE_PICKLEBALL` from GitHub at [vercel.com](https://vercel.com).
2. Vercel reads `vercel.json` and runs `scripts/vercel-build.sh`.
3. **Do not set `API_BASE_URL` to an external host** unless you intentionally use a separate API. Leave it unset — the build auto-sets it to `https://<your-vercel-domain>/api`.

### 2. Required Vercel environment variables

Add these in **Project → Settings → Environment Variables**:

| Variable | Example | Required |
|----------|---------|----------|
| `APP_KEY` | From `php artisan key:generate --show` | Yes |
| `APP_ENV` | `production` | Yes |
| `APP_DEBUG` | `false` | Yes |
| `APP_URL` | `https://rbe-pickleball.vercel.app` | Yes |
| `ADMIN_PIN` | Strong PIN (not `1234`) | Yes |
| `DB_CONNECTION` | `mysql` | Yes |
| `DB_HOST` | From your MySQL provider | Yes |
| `DB_PORT` | `3306` | Yes |
| `DB_DATABASE` | `rpc_queue` | Yes |
| `DB_USERNAME` | … | Yes |
| `DB_PASSWORD` | … | Yes |

Optional:

| Variable | Purpose |
|----------|---------|
| `API_BASE_URL` | Override auto same-origin URL (usually leave unset) |
| `WS_HOST` / `WS_SCHEME` / `WS_KEY` | Reverb WebSockets (optional; polling works without) |

**Database:** Vercel does not include MySQL. You must add a hosted MySQL database and paste the connection vars above. Without this, `/api/health` works but admin pages show **Server Error**.

#### Quick MySQL setup (TiDB Cloud — free tier)

1. Go to [tidbcloud.com](https://tidbcloud.com) and create a free **Serverless** cluster.
2. Create database `rpc_queue` in the console.
3. Copy the MySQL connection host, user, password, and port.
4. In **Vercel → Settings → Environment Variables**, add:

```
DB_CONNECTION=mysql
DB_HOST=gateway01.us-west-2.prod.aws.tidbcloud.com   (your host)
DB_PORT=4000                                          (TiDB often uses 4000)
DB_DATABASE=rpc_queue
DB_USERNAME=your_user
DB_PASSWORD=your_password
```

5. Also set `APP_KEY`, `ADMIN_PIN`, `APP_URL`, `APP_ENV=production`, `APP_DEBUG=false`.
6. **Redeploy** — migrations run automatically during build when `DB_HOST` is set.
7. Verify: `https://your-app.vercel.app/api/health/db` → `{"status":"ok","database":"connected"}`

**Remove** any old `API_BASE_URL` pointing to Railway or other external hosts, then redeploy.

### 3. Deploy and verify

1. Click **Deploy** (first build ~5–10 min).
2. Test API: `https://your-app.vercel.app/api/health` → `{"status":"ok"}`
3. Test database: `https://your-app.vercel.app/api/health/db` → `database: connected`
4. Test app: `https://your-app.vercel.app/#/admin`

### 4. Public URLs (share or QR code)

| Audience | URL |
|----------|-----|
| Admin | `https://your-app.vercel.app/#/admin` |
| Public board | `https://your-app.vercel.app/#/board` |
| Check-in | Generated in admin (uses deployed origin) |
| Court display | `https://your-app.vercel.app/#/court?n=1` |
| Tournament display | `https://your-app.vercel.app/#/tournament-display` |

### 5. Runtime configuration

`frontend/web/env-config.js` is generated at build time. When `API_BASE_URL` is not set, it uses `https://<VERCEL_URL>/api` automatically.

Priority: **Vercel env `API_BASE_URL`** → **auto same-origin `/api`** → **`--dart-define`** → local dev `localhost:8000`.

### 6. Local build + Vercel CLI

```powershell
# Windows
$env:API_BASE_URL = "http://localhost:8000/api"
.\scripts\build-web.ps1
npx vercel --prod
```

```bash
# macOS/Linux
export API_BASE_URL=http://localhost:8000/api
bash scripts/vercel-build.sh
```

### 7. Production checklist

- [ ] Removed external `API_BASE_URL` (Railway, etc.) from Vercel env
- [ ] `APP_KEY`, `ADMIN_PIN`, and `DB_*` set on Vercel
- [ ] `/api/health` returns OK on your Vercel URL
- [ ] Admin, board, check-in QR, and tournament flows tested
- [ ] `APP_DEBUG=false`

### Local development

```bash
cd backend && php artisan serve
cd frontend && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api
```

Default admin PIN for local dev: **1234** (set `ADMIN_PIN` in `backend/.env`).

## VPS Deployment (optional)

For self-hosted full-stack on a single VPS (Nginx + PHP + MySQL + static Flutter build), see legacy steps: provision Ubuntu, point Nginx to `backend/public`, serve `frontend/build/web`, run Reverb optionally.

### Nginx WebSocket proxy snippet

```nginx
location /app {
    proxy_pass http://127.0.0.1:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "Upgrade";
    proxy_set_header Host $host;
}
```

## Running Tests

```bash
cd backend
php artisan test
```

```bash
cd frontend
flutter test
```

## Domain Rules Summary

- **New players:** alternate Winners → Losers → Winners in **pairs of two** (players 1–2 → Winners, 3–4 → Losers, 5–6 → Winners, …)
- **Court assignment:** alternate queue per assignment
- **Partner continuity:** teammates once, opponents next time grouped
- **Insufficient queue depth:** court stays empty (admin can manual-assign)
