/// PC LAN IP for local Android dev only (with `USE_LOCAL_API=true`).
///
/// Override at build/run time:
/// `--dart-define=DEV_API_HOST=192.168.x.x`
const devApiHost = String.fromEnvironment(
  'DEV_API_HOST',
  defaultValue: '',
);
