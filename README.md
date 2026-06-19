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
├── backend/     # Laravel API (deploy separately from Vercel)
├── frontend/    # Flutter web app (Admin + Board views)
├── scripts/     # Vercel/CI build helpers
├── vercel.json  # Vercel frontend deployment config
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

## VPS Deployment (DigitalOcean / Hostinger)

1. Provision Ubuntu VPS with Nginx, PHP 8.2+, MySQL, Composer.
2. Clone repo and configure `backend/.env` for production DB and `APP_URL`.
3. Run `composer install --no-dev`, `php artisan migrate --force`, `php artisan config:cache`.
4. Point Nginx to `backend/public`.
5. Build Flutter web: `flutter build web --dart-define=API_BASE_URL=https://your-domain.com/api`
6. Serve `frontend/build/web` via Nginx static site or subdirectory.
7. Optional: run Reverb as a systemd service and proxy WebSocket on `/app`.

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

## Vercel Deployment (Frontend)

The Flutter web app deploys to **Vercel**. The Laravel API must run on a separate host (VPS, Railway, Render, Fly.io, etc.) with a managed MySQL database.

### Architecture

```
Vercel (Flutter static)  ──HTTPS──►  API host (Laravel + MySQL)
https://your-app.vercel.app          https://api.yourdomain.com/api
```

### 1. Deploy the API

1. Host `backend/` on your API provider (see `backend/Procfile` for a minimal Railway/Render start command).
2. Set production `.env` values:

```
APP_ENV=production
APP_DEBUG=false
APP_URL=https://api.yourdomain.com
DB_CONNECTION=mysql
DB_HOST=...
ADMIN_PIN=your-strong-pin
FRONTEND_URL=https://your-app.vercel.app
```

3. Run migrations: `php artisan migrate --force`

Verify: `GET https://api.yourdomain.com/api/health`

### 2. Deploy the frontend to Vercel

**Option A — Connect repo to Vercel (recommended)**

1. Import this repository in [Vercel](https://vercel.com).
2. Set **Root Directory** to the repo root (default).
3. Vercel reads `vercel.json` and runs `scripts/vercel-build.sh` (installs Flutter if needed).
4. Add **Environment Variables** in the Vercel project:

| Variable | Example | Required |
|----------|---------|----------|
| `API_BASE_URL` | `https://api.yourdomain.com/api` | Yes |
| `WS_HOST` | `api.yourdomain.com` | Only if using Reverb |
| `WS_SCHEME` | `wss` | Only if using Reverb |
| `WS_KEY` | `rpc-key` | Only if using Reverb |

5. Deploy. Vercel provides a public URL like `https://your-app.vercel.app`.

**Option B — GitHub Actions**

Set repository **Variables** (`API_BASE_URL`, etc.) and **Secrets** (`VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`). Pushes to `main` run `.github/workflows/deploy-vercel.yml`.

**Option C — Local build + Vercel CLI**

```powershell
# Windows
$env:API_BASE_URL = "https://api.yourdomain.com/api"
.\scripts\build-web.ps1
```

```bash
# macOS/Linux
export API_BASE_URL=https://api.yourdomain.com/api
bash scripts/vercel-build.sh
```

### 3. Public URLs (share or QR code)

| Audience | URL |
|----------|-----|
| Admin | `https://your-app.vercel.app/#/admin` |
| Public board | `https://your-app.vercel.app/#/board` |
| Check-in | Generated in admin (uses deployed origin automatically) |
| Court display | `https://your-app.vercel.app/#/court?n=1` |
| Tournament display | `https://your-app.vercel.app/#/tournament-display` |

Hash routes work on static hosting without extra server config.

### 4. Runtime configuration

`frontend/web/env-config.js` is generated at build time from Vercel environment variables. It is loaded before Flutter starts, so you can change `API_BASE_URL` in Vercel and redeploy without editing source code.

Priority: **runtime env-config.js** → **`--dart-define`** → local dev defaults.

### 5. Production checklist

- [ ] `API_BASE_URL` points to HTTPS API (not localhost)
- [ ] `ADMIN_PIN` changed from default on the API
- [ ] `APP_DEBUG=false` on the API
- [ ] Managed MySQL (not SQLite)
- [ ] `FRONTEND_URL` set on API for CORS (optional; omit to allow all origins)
- [ ] Test admin login, board polling, check-in QR, tournament flow
- [ ] Optional Reverb: `WS_SCHEME=wss`, proxy `/app` on API host

### Local development (unchanged)

```bash
cd backend && php artisan serve
cd frontend && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api
```

Default admin PIN for local dev: **1234** (set `ADMIN_PIN` in `backend/.env`).

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
