import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../app_config.dart';
import 'market_data_service.dart';

class MarketSocketService {
  io.Socket? _socket;
  bool _hasConnectedOnce = false;

  Function(Map<String, dynamic>)? onQuoteUpdate;
  VoidCallback? onConnected;
  VoidCallback? onDisconnected;

  bool get isConnected => _socket?.connected == true;

  void connect() {
    if (_socket != null) {
      return;
    }

    final socket = io.io(
      AppConfig.apiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket = socket;

    socket.onConnect((_) {
      _debugLog('Market websocket connected');
      onConnected?.call();

      if (_hasConnectedOnce) {
        _refreshSnapshotAfterReconnect();
      } else {
        _hasConnectedOnce = true;
      }
    });

    socket.on('market-update', (data) {
      if (data is Map) {
        final quote = Map<String, dynamic>.from(data);
        if (!MarketDataService.acceptsRealtimeQuote(quote)) {
          _debugLog('Ignored non-preferred exchange tick $quote');
          return;
        }
        _debugLog('Market update $quote');
        onQuoteUpdate?.call(quote);
      }
    });

    socket.onDisconnect((_) {
      _debugLog('Market websocket disconnected');
      onDisconnected?.call();
    });

    socket.onConnectError((error) {
      _debugLog('Market websocket connect error: $error');
    });

    socket.onError((error) {
      _debugLog('Market websocket error: $error');
    });

    socket.connect();
  }

  Future<void> _refreshSnapshotAfterReconnect() async {
    try {
      final stocks = await MarketDataService().fetchSnapshot();
      for (final stock in stocks) {
        onQuoteUpdate?.call({
          'type': 'STOCK',
          'symbol': stock.symbol,
          'price': stock.price,
          'change': stock.change,
          'volume': stock.volume,
          'updatedAt': stock.updatedAt.toIso8601String(),
        });
      }
      _debugLog('Market snapshot refreshed after reconnect');
    } catch (error) {
      _debugLog('Market snapshot refresh failed: $error');
    }
  }

  void dispose() {
    onQuoteUpdate = null;
    onConnected = null;
    onDisconnected = null;
    _socket?.dispose();
    _socket = null;
    _hasConnectedOnce = false;
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
