import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../app_config.dart';
import 'auth_service.dart';
import 'market_data_service.dart';

typedef MarketQuoteListener = void Function(Map<String, dynamic> quote);
typedef MarketConnectionListener = void Function(bool connected);

class MarketSocketService with WidgetsBindingObserver {
  factory MarketSocketService() => _instance;

  MarketSocketService._();

  static final MarketSocketService _instance = MarketSocketService._();

  io.Socket? _socket;
  Future<void>? _connectInFlight;
  bool _observingLifecycle = false;
  Future<void>? _snapshotRefreshInFlight;
  DateTime? _lastResumeAt;
  DateTime? _lastServerActivityAt;
  Timer? _connectionWatchdog;
  final Map<String, DateTime> _latestQuoteAt = <String, DateTime>{};
  final Set<MarketQuoteListener> _quoteListeners = <MarketQuoteListener>{};
  final Set<MarketConnectionListener> _connectionListeners =
      <MarketConnectionListener>{};

  Function(Map<String, dynamic>)? onQuoteUpdate;
  VoidCallback? onConnected;
  VoidCallback? onDisconnected;

  bool get isConnected => _socket?.connected == true;
  bool get hasStarted => _socket != null;

  void addQuoteListener(MarketQuoteListener listener) {
    _quoteListeners.add(listener);
  }

  void removeQuoteListener(MarketQuoteListener listener) {
    _quoteListeners.remove(listener);
  }

  void addConnectionListener(MarketConnectionListener listener) {
    _connectionListeners.add(listener);
  }

  void removeConnectionListener(MarketConnectionListener listener) {
    _connectionListeners.remove(listener);
  }

  void connect() {
    if (_connectInFlight != null) return;

    final attempt = _connectAuthenticated();
    _connectInFlight = attempt;
    unawaited(
      attempt.whenComplete(() {
        if (identical(_connectInFlight, attempt)) {
          _connectInFlight = null;
        }
      }),
    );
  }

  Future<void> _connectAuthenticated() async {
    _ensureLifecycleObserver();

    if (_socket != null) {
      if (_socket?.connected != true) {
        _socket?.connect();
      }
      return;
    }

    final session = await AuthService().restoreSession();
    if (session == null || session.accessToken.isEmpty) {
      _emitConnection(false);
      return;
    }
    final socket = io.io(
      AppConfig.apiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(1000000)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(30000)
          .setTimeout(10000)
          .setAuth({'token': session.accessToken})
          .disableAutoConnect()
          .build(),
    );

    _socket = socket;

    socket.onConnect((_) {
      _lastServerActivityAt = DateTime.now();
      _startConnectionWatchdog();
      _debugLog('Market websocket connected');
      _emitConnection(true);
      onConnected?.call();

      refreshSnapshot();
    });

    socket.on('market-update', (data) {
      _lastServerActivityAt = DateTime.now();
      if (data is Map) {
        final quote = Map<String, dynamic>.from(data);
        _debugLog('Market update $quote');
        _emitQuote(quote);
      }
    });

    socket.on('market-heartbeat', (_) {
      _lastServerActivityAt = DateTime.now();
    });

    socket.onDisconnect((_) {
      _debugLog('Market websocket disconnected');
      _emitConnection(false);
      onDisconnected?.call();
    });

    socket.onConnectError((error) {
      _debugLog('Market websocket connect error: $error');
      _emitConnection(false);
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
      final service = MarketDataService();
      final results = await Future.wait<dynamic>([
        service.fetchSnapshot(),
        service.fetchIndexSnapshot(),
      ]);
      final stocks = results[0] as List;
      final indices = results[1] as List<Map<String, dynamic>>;

      for (final stock in stocks) {
        _emitQuote({
          'type': 'STOCK',
          'symbol': stock.symbol,
          'exchange': stock.exchange,
          'price': stock.price,
          'change': stock.change,
          'volume': stock.volume,
          'previousClose': stock.previousClose,
          'openPrice': stock.open,
          'highPrice': stock.high,
          'lowPrice': stock.low,
          'bidPrice': stock.bid,
          'askPrice': stock.ask,
          'updatedAt': stock.updatedAt.toIso8601String(),
        });
      }
      for (final index in indices) {
        _emitQuote(index);
      }
      _debugLog('Market snapshot refreshed');
    } catch (error) {
      _debugLog('Market snapshot refresh failed: $error');
    }
  }

  void _emitQuote(Map<String, dynamic> quote) {
    final symbol = quote['symbol']?.toString().trim().toUpperCase() ?? '';
    final exchange = quote['exchange']?.toString().trim().toUpperCase() ?? '';
    final type = quote['type']?.toString().trim().toUpperCase() ?? 'STOCK';
    final updatedAt = DateTime.tryParse(quote['updatedAt']?.toString() ?? '');
    if (symbol.isEmpty || updatedAt == null) return;
    if (updatedAt.isAfter(DateTime.now().add(const Duration(minutes: 2)))) {
      return;
    }
    final key = '$type:$exchange:$symbol';
    final latest = _latestQuoteAt[key];
    if (latest != null && updatedAt.isBefore(latest)) return;
    _latestQuoteAt[key] = updatedAt;

    onQuoteUpdate?.call(quote);
    for (final listener in List<MarketQuoteListener>.from(_quoteListeners)) {
      listener(quote);
    }
  }

  void _emitConnection(bool connected) {
    for (final listener in List<MarketConnectionListener>.from(
      _connectionListeners,
    )) {
      listener(connected);
    }
  }

  void dispose() {
    onQuoteUpdate = null;
    onConnected = null;
    onDisconnected = null;
    _quoteListeners.clear();
    _connectionListeners.clear();
    _socket?.dispose();
    _socket = null;
    _connectInFlight = null;
    _snapshotRefreshInFlight = null;
    _lastResumeAt = null;
    _lastServerActivityAt = null;
    _connectionWatchdog?.cancel();
    _connectionWatchdog = null;
    _latestQuoteAt.clear();
    _removeLifecycleObserver();
  }

  void _startConnectionWatchdog() {
    _connectionWatchdog?.cancel();
    _connectionWatchdog = Timer.periodic(const Duration(seconds: 15), (_) {
      final socket = _socket;
      final lastActivity = _lastServerActivityAt;
      if (socket == null || !socket.connected || lastActivity == null) return;
      if (DateTime.now().difference(lastActivity) <=
          const Duration(seconds: 50))
        return;
      _debugLog('Market websocket heartbeat timed out; reconnecting');
      socket.disconnect();
      socket.connect();
    });
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
