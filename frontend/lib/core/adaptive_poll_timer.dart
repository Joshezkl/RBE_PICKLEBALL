import 'dart:async';

import 'page_visibility.dart';

/// Polls on an interval that adapts to tab visibility and live update status.
class AdaptivePollTimer {
  AdaptivePollTimer({
    required Future<void> Function() onPoll,
    this.foregroundInterval = const Duration(seconds: 5),
    this.backgroundInterval = const Duration(seconds: 15),
    this.liveInterval = const Duration(seconds: 20),
  }) : _onPoll = onPoll;

  final Duration foregroundInterval;
  final Duration backgroundInterval;
  final Duration liveInterval;

  final Future<void> Function() _onPoll;
  Timer? _timer;
  bool _liveUpdatesActive = false;
  bool _inFlight = false;

  void start() {
    stop();
    rpcPageVisibility.addListener(_restart);
    _restart();
  }

  void stop() {
    rpcPageVisibility.removeListener(_restart);
    _timer?.cancel();
    _timer = null;
  }

  void setLiveUpdatesActive(bool active) {
    if (_liveUpdatesActive == active) {
      return;
    }
    _liveUpdatesActive = active;
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval(), (_) => _tick());
  }

  Duration _interval() {
    if (!rpcPageVisibility.isVisible) {
      return backgroundInterval;
    }
    if (_liveUpdatesActive) {
      return liveInterval;
    }
    return foregroundInterval;
  }

  Future<void> _tick() async {
    if (_inFlight) {
      return;
    }

    _inFlight = true;
    try {
      await _onPoll();
    } catch (_) {
      // Polling is best-effort; controllers surface errors on explicit actions.
    } finally {
      _inFlight = false;
    }
  }
}
