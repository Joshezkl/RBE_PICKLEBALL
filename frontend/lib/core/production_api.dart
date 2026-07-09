/// Always-on hosted API used by mobile release builds.
///
/// Override at build time:
/// `--dart-define=PRODUCTION_API_BASE_URL=https://your-app.vercel.app/api`
const productionApiBaseUrl = String.fromEnvironment(
  'PRODUCTION_API_BASE_URL',
  defaultValue: 'https://rbe-pickleball.vercel.app/api',
);

/// When true, mobile builds use a local dev machine (`localhost` / LAN IP)
/// instead of [productionApiBaseUrl].
const useLocalApi = bool.fromEnvironment('USE_LOCAL_API', defaultValue: false);
