import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';
import 'models.dart';

class LiveUpdateService {
  WebSocketChannel? _channel;

  void connect({
    required int sessionId,
    required void Function(SessionState state) onState,
  }) {
    disconnect();

    final uri = Uri.parse(
      'ws://${AppConfig.wsHost}/app/${AppConfig.wsKey}?protocol=7&client=js&version=8.4.0',
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      _channel!.sink.add(jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'channel': 'session.$sessionId'},
      }));

      _channel!.stream.listen((message) {
        try {
          final payload = jsonDecode(message as String) as Map<String, dynamic>;
          if (payload['event'] == 'SessionStateUpdated') {
            final data = payload['data'];
            final Map<String, dynamic> stateJson = data is String
                ? jsonDecode(data) as Map<String, dynamic>
                : Map<String, dynamic>.from(data as Map);
            onState(SessionState.fromJson(stateJson));
          }
        } catch (_) {}
      });
    } catch (_) {
      // Polling remains the primary update path when Reverb is unavailable.
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
