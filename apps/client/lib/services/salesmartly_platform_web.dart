import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../models/auth_session.dart';
import 'salesmartly_platform.dart';

SaleSmartlyPlatform createSaleSmartlyPlatform() =>
    _SaleSmartlyWebPlatform.instance;

/// Flutter Web bridge using the official SaleSmartly JSSDK (`ssq` queue).
final class _SaleSmartlyWebPlatform implements SaleSmartlyPlatform {
  _SaleSmartlyWebPlatform._();
  static final _SaleSmartlyWebPlatform instance = _SaleSmartlyWebPlatform._();

  static const _scriptElementId = 'hnw-salesmartly-js';
  static const _unavailable =
      'Customer support is temporarily unavailable. Please try again.';
  static const _loadTimeout = Duration(seconds: 20);
  static const _commandTimeout = Duration(seconds: 15);

  Future<void>? _loading;
  String? _loadedScriptUrl;
  bool _unreadListenerAttached = false;
  /// Prevents auto-preset spam when openChat is called repeatedly for the
  /// same user + same CMS message in one browser session.
  String? _lastAutoPresetKey;

  /// Internal unread count from `onUnRead` (no dedicated badge UI yet).
  int unreadCount = 0;

  @override
  Future<void> openChat({
    required String scriptUrl,
    required AuthSession session,
    String? initialMessage,
  }) async {
    if (scriptUrl.isEmpty) {
      throw const SaleSmartlyException(_unavailable);
    }
    try {
      await _ensureSdkLoaded(scriptUrl);
      await _setLoginInfo(session);
      final status = await _pushCommand('chatOpen');
      if (status == 'failed') {
        throw const SaleSmartlyException(_unavailable);
      }
      // ignored = already open / duplicate — not fatal.
      final message = initialMessage?.trim() ?? '';
      if (message.isNotEmpty) {
        final presetKey = '${session.userId}::$message';
        if (_lastAutoPresetKey != presetKey) {
          await _pushCommand('sendTextMessage', payload: message.toJS);
          _lastAutoPresetKey = presetKey;
        }
      }
    } on SaleSmartlyException {
      rethrow;
    } catch (_) {
      throw const SaleSmartlyException(_unavailable);
    }
  }

  @override
  Future<void> clearUser() async {
    try {
      if (_loadedScriptUrl == null &&
          web.document.getElementById(_scriptElementId) == null) {
        _lastAutoPresetKey = null;
        return;
      }
      await _pushCommand('chatClose');
      await _pushCommand('clearUser');
    } catch (_) {
      // Logout must succeed even if the vendor SDK is unavailable.
    } finally {
      _lastAutoPresetKey = null;
    }
  }

  @override
  Future<void> closeChat() async {
    try {
      await _pushCommand('chatClose');
    } catch (_) {}
  }

  Future<void> _ensureSdkLoaded(String scriptUrl) async {
    if (_loadedScriptUrl == scriptUrl &&
        web.document.getElementById(_scriptElementId) != null &&
        _vendorSsqReady()) {
      _ensureHideIcon();
      _attachUnreadListener();
      return;
    }
    if (_loadedScriptUrl != null && _loadedScriptUrl != scriptUrl) {
      // Script URL changed — force a fresh load.
      web.document.getElementById(_scriptElementId)?.remove();
      web.document.getElementById('ss-chat')?.remove();
      _loadedScriptUrl = null;
      _unreadListenerAttached = false;
      _loading = null;
      _clearVendorGlobals();
    }
    // Stale DOM script without vendor ssq (e.g. prior aborted bootstrap).
    if (web.document.getElementById(_scriptElementId) != null &&
        !_vendorSsqReady()) {
      web.document.getElementById(_scriptElementId)?.remove();
      web.document.getElementById('ss-chat')?.remove();
      _loadedScriptUrl = null;
      _loading = null;
    }
    _loading ??= _loadScript(scriptUrl);
    try {
      await _loading;
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  Future<void> _loadScript(String scriptUrl) async {
    _ensureHideIcon();
    // Do NOT pre-create window.ssq. SaleSmartly project_*.js aborts with
    // `if (w.ssq) return false` and never loads /chat/widget-v2/code/install.js.

    final existing = web.document.getElementById(_scriptElementId);
    if (existing != null && _vendorSsqReady()) {
      _loadedScriptUrl = scriptUrl;
      _attachUnreadListener();
      return;
    }

    final ready = Completer<void>();
    final timeout = Timer(_loadTimeout, () {
      if (!ready.isCompleted) {
        ready.completeError(StateError('timeout'));
      }
    });

    final script = web.HTMLScriptElement()
      ..id = _scriptElementId
      ..async = true
      ..src = scriptUrl;

    script.onError.listen((_) {
      if (!ready.isCompleted) {
        ready.completeError(StateError('load_failed'));
      }
    });

    script.onLoad.listen((_) {
      // Bootstrap runs synchronously on evaluate; register onReady afterward.
      try {
        _pushRaw(
          'onReady',
          null,
          ((JSAny? _) {
            if (!ready.isCompleted) ready.complete();
          }).toJS,
        );
      } catch (_) {
        if (!ready.isCompleted) {
          ready.completeError(StateError('ssq_missing'));
        }
      }
    });

    (web.document.head ?? web.document.body)!.append(script);

    try {
      await ready.future;
      _loadedScriptUrl = scriptUrl;
      _ensureHideIcon();
      _attachUnreadListener();
    } catch (_) {
      script.remove();
      // Vendor also injects #ss-chat for install.js — remove stale copies.
      web.document.getElementById('ss-chat')?.remove();
      _loadedScriptUrl = null;
      _unreadListenerAttached = false;
      _clearVendorGlobals();
      _ensureHideIcon();
      throw const SaleSmartlyException(_unavailable);
    } finally {
      timeout.cancel();
      _loading = null;
    }
  }

  bool _vendorSsqReady() {
    final current = globalContext.getProperty('ssq'.toJS);
    return current != null && !current.isUndefinedOrNull;
  }

  void _clearVendorGlobals() {
    // Delete ssq so Retry can load a fresh bootstrap (array stubs break init).
    try {
      final reflect = globalContext.getProperty('Reflect'.toJS) as JSObject;
      reflect.callMethod('deleteProperty'.toJS, globalContext, 'ssq'.toJS);
    } catch (_) {
      globalContext.setProperty('ssq'.toJS, null);
    }
  }

  void _ensureSsqQueue() {
    // After vendor bootstrap, ssq is a function stub with .push. Never replace
    // it with an Array — that prevents re-init and breaks command delivery.
    if (!_vendorSsqReady()) {
      throw StateError('ssq missing');
    }
  }

  void _ensureHideIcon() {
    // Official supported launcher hide (`window.__ssc.setting.hideIcon`).
    final JSObject ssc;
    final existing = globalContext.getProperty('__ssc'.toJS);
    if (existing == null || existing.isUndefinedOrNull) {
      ssc = JSObject();
      globalContext.setProperty('__ssc'.toJS, ssc);
    } else {
      ssc = existing as JSObject;
    }
    final setting = JSObject()..setProperty('hideIcon'.toJS, true.toJS);
    ssc.setProperty('setting'.toJS, setting);
  }

  Future<void> _setLoginInfo(AuthSession session) async {
    final payload = JSObject()
      ..setProperty('user_id'.toJS, session.userId.toJS)
      ..setProperty('user_name'.toJS, session.fullName.toJS)
      ..setProperty('language'.toJS, 'en'.toJS)
      ..setProperty('phone'.toJS, session.phone.trim().toJS)
      ..setProperty('email'.toJS, ''.toJS)
      ..setProperty('description'.toJS, 'India Trading customer'.toJS)
      ..setProperty(
        'label_names'.toJS,
        <JSAny?>['hnw'.toJS, 'web'.toJS].toJS,
      );

    final status = await _pushCommand('setLoginInfo', payload: payload);
    if (status == 'failed') {
      throw const SaleSmartlyException(_unavailable);
    }
  }

  void _attachUnreadListener() {
    if (_unreadListenerAttached) return;
    _unreadListenerAttached = true;
    _pushRaw(
      'onUnRead',
      null,
      ((JSAny? raw) {
        if (raw == null || raw.isUndefinedOrNull) return;
        final obj = raw as JSObject;
        final numValue = obj.getProperty('num'.toJS);
        if (numValue != null && !numValue.isUndefinedOrNull) {
          unreadCount = (numValue as JSNumber).toDartInt;
        }
      }).toJS,
    );
  }

  Future<String> _pushCommand(String command, {JSAny? payload}) async {
    _ensureSsqQueue();
    final completer = Completer<String>();
    final timer = Timer(_commandTimeout, () {
      if (!completer.isCompleted) completer.complete('failed');
    });

    final callback = ((JSAny? raw) {
      if (completer.isCompleted) return;
      var status = 'success';
      if (raw != null && !raw.isUndefinedOrNull) {
        final value = (raw as JSObject).getProperty('status'.toJS);
        if (value != null && !value.isUndefinedOrNull) {
          status = (value as JSString).toDart;
        }
      }
      completer.complete(status);
    }).toJS;

    try {
      _pushRaw(command, payload, callback);
    } catch (_) {
      timer.cancel();
      return 'failed';
    }

    final status = await completer.future;
    timer.cancel();
    return status;
  }

  void _pushRaw(String command, JSAny? payload, JSFunction? callback) {
    final ssq = globalContext.getProperty('ssq'.toJS);
    if (ssq == null || ssq.isUndefinedOrNull) {
      throw StateError('ssq missing');
    }
    final target = ssq as JSObject;
    if (payload != null && callback != null) {
      target.callMethod('push'.toJS, command.toJS, payload, callback);
    } else if (payload != null) {
      target.callMethod('push'.toJS, command.toJS, payload);
    } else if (callback != null) {
      target.callMethod('push'.toJS, command.toJS, callback);
    } else {
      target.callMethod('push'.toJS, command.toJS);
    }
  }
}
