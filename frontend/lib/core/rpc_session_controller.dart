import 'api_client.dart';
import 'session_controller.dart';

/// Shared session state for the whole app.
///
/// Admin screens, the public board, and the displays hub all read the same
/// active session instead of creating (and disposing) a controller per route,
/// which previously refetched on every navigation.
final rpcSessionController = SessionController();

/// Shared API client backing [rpcSessionController]. All screens should use
/// this instance so the in-memory [DataCache] is shared across navigation.
ApiClient get rpcApiClient => rpcSessionController.api;
