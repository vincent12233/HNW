import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../app_config.dart';
import 'market_data_service.dart';

class MarketSocketService with WidgetsBindingObserver {
  factory MarketSocketService() => _instance;

  MarketSocketService._();

  static final MarketSocketService _instance = MarketSocketService._();

  io.Socket? _socket;
  bool _hasConnectedOnce = false;
  bool _observingLifecycle = false;
  Future<void>? _snapshotRefreshInFlight;
  DateTime? _lastResumeAt;

  Function(Map<String, dynamic>)? onQuoteUpdate;
  VoidCallback? onConnected;
  VoidCallback? onDisconnected;

  bool get isConnected => _socket?.connected == true;

  void connect() {
    _ensureLifecycleObserver();

    if (_socket != null) {
      if (_socket?.connected != true) {
        _socket?.connect();
      }
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
        refreshSnapshot();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _socket != null) {
      resume();
    }
  }

  Future<void> resume() async {
    final now = DateTime.now();
    final lastResumeAt = _lastResumeAt;
    if (lastResumeAt != null &&
        now.difference(lastResumeAt) < const Duration(seconds: 1)) {
      return;
    }
    _lastResumeAt = now;

    final socket = _socket;
    if (socket == null) {
      connect();
      return;
    }

    if (!socket.connected) {
      socket.connect();
      return;
    }

    await refreshSnapshot();
  }

  Future<void> refreshSnapshot() {
    final inFlight = _snapshotRefreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final refresh = _performSnapshotRefresh();
    _snapshotRefreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_snapshotRefreshInFlight, refresh)) {
        _snapshotRefreshInFlight = null;
      }
    });
  }

  Future<void> _performSnapshotRefresh() async {
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
      _debugLog('Market snapshot refreshed');
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
    _snapshotRefreshInFlight = null;
    _lastResumeAt = null;
    _removeLifecycleObserver();
  }

  void _ensureLifecycleObserver() {
    if (_observingLifecycle) return;
    WidgetsBinding.instance.addObserver(this);
    _observingLifecycle = true;
  }

  void _removeLifecycleObserver() {
    if (!_observingLifecycle) return;
    WidgetsBinding.instance.removeObserver(this);
    _observingLifecycle = false;
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
