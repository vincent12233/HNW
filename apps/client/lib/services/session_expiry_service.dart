import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'market_socket_service.dart';

class SessionExpiryService {
  factory SessionExpiryService() => _instance;

  SessionExpiryService._();

  static final SessionExpiryService _instance = SessionExpiryService._();
  static const String _sessionKey = 'auth_session';

  VoidCallback? onExpired;
  Future<void>? _expiryInFlight;

  bool isUnauthorized(int statusCode) => statusCode == 401;

  Future<void> expire() {
    final inFlight = _expiryInFlight;
    if (inFlight != null) return inFlight;

    final expiry = _performExpiry();
    _expiryInFlight = expiry;
    return expiry.whenComplete(() {
      if (identical(_expiryInFlight, expiry)) {
        _expiryInFlight = null;
      }
    });
  }

  Future<void> _performExpiry() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
    MarketSocketService().dispose();
    onExpired?.call();
  }
}
