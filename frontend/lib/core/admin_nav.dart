import 'widgets/rpc_shell.dart';

/// Standard admin navigation — Dashboard, Players, Stats, History, Displays.
const adminNavDestinations = [
  RpcNavDestination.dashboard,
  RpcNavDestination.players,
  RpcNavDestination.tournaments,
  RpcNavDestination.stats,
  RpcNavDestination.history,
  RpcNavDestination.revenue,
  RpcNavDestination.displays,
];

/// Public venue navigation — live board and club rankings.
const publicNavDestinations = [
  RpcNavDestination.publicBoard,
  RpcNavDestination.publicStats,
];
