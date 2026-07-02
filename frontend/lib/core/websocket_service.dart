import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';
import 'models.dart';

class LiveUpdateService {
  WebSocketChannel? _channel;
  bool _connected = false;

  bool get isConnected => _connected;

  void connect({
    required int sessionId,
    required void Function(SessionState state) onState,
    void Function(bool connected)? onConnectionChanged,
  }) {
    if (!AppConfig.liveUpdatesEnabled) {
      _markDisconnected(onConnectionChanged);
      return;
    }

    disconnect(onConnectionChanged: onConnectionChanged);

    final uri = Uri.parse(
      '${AppConfig.wsScheme}://${AppConfig.wsHost}/app/${AppConfig.wsKey}?protocol=7&client=js&version=8.4.0',
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      _channel!.sink.add(jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'channel': 'session.$sessionId'},
      }));

      _channel!.stream.listen(
        (message) {
          try {
            final payload =
                jsonDecode(message as String) as Map<String, dynamic>;
            final event = payload['event'] as String?;

            if (!_connected &&
                (event == 'pusher:connection_established' ||
                    event == 'SessionStateUpdated')) {
              _connected = true;
              onConnectionChanged?.call(true);
            }

            if (event == 'SessionStateUpdated') {
              final data = payload['data'];
              final Map<String, dynamic> stateJson = data is String
                  ? jsonDecode(data) as Map<String, dynamic>
                  : Map<String, dynamic>.from(data as Map);
              onState(SessionState.fromJson(stateJson));
            }
          } catch (_) {}
        },
        onDone: () => _markDisconnected(onConnectionChanged),
        onError: (_) => _markDisconnected(onConnectionChanged),
      );
    } catch (_) {
      // Polling remains the primary update path when Reverb is unavailable.
      _markDisconnected(onConnectionChanged);
    }
  }

  void disconnect({void Function(bool connected)? onConnectionChanged}) {
    _channel?.sink.close();
    _channel = null;
    if (_connected) {
      _connected = false;
      onConnectionChanged?.call(false);
    }
  }

  void _markDisconnected(void Function(bool connected)? onConnectionChanged) {
    if (!_connected) {
      return;
    }
    _connected = false;
    onConnectionChanged?.call(false);
  }
}
