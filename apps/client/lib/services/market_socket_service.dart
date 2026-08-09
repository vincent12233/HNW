import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../app_config.dart';

class MarketSocketService {
  late io.Socket socket;

  Function(Map<String, dynamic>)? onQuoteUpdate;

  void connect() {
    socket = io.io(
      AppConfig.apiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      _debugLog('Market websocket connected');
    });

    socket.on('market-update', (data) {
      if (data is Map) {
        final quote = Map<String, dynamic>.from(data);
        _debugLog('Market update $quote');
        onQuoteUpdate?.call(quote);
      }
    });

    socket.onDisconnect((_) {
      _debugLog('Market websocket disconnected');
    });

    socket.onError((error) {
      _debugLog('Websocket error: $error');
    });
  }

  void dispose() {
    socket.dispose();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
