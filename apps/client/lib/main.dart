import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_language.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'models/auth_session.dart';
import 'pages/login_page.dart';
import 'pages/market_page.dart';
import 'pages/register_page.dart';
import 'pages/splash_page.dart';
import 'services/app_client_settings_service.dart';
import 'services/auth_service.dart';
import 'services/local_data_cache.dart';
import 'services/session_expiry_service.dart';
import 'theme/app_theme.dart';
import 'theme/appearance_settings.dart';
import 'widgets/app_settings_gates.dart';
import 'services/app_version.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguage.instance.load();
  await AppearanceSettings.instance.load();
  await AppClientSettingsService.instance.bootstrap();
  SessionExpiryService().onExpired = _showExpiredSessionLogin;

  ErrorWidget.builder = (details) {
    return const Material(
      color: AppConfig.backgroundColor,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.dashboard_customize_outlined,
                color: AppConfig.primaryColor,
                size: 48,
              ),
              SizedBox(height: 12),
              Text(
                'Content is temporarily unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 6),
              Text(
                'Please refresh or switch tabs.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppConfig.neutralColor),
              ),
            ],
          ),
        ),
      ),
    );
  };

  runApp(const IndiaTradingApp());
}

void _showExpiredSessionLogin() {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return;

  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) => LoginPage(
        notice: 'Your session has expired. Please sign in again.',
        onSignedIn: (_) {
          marketSocket.connect();
          navigator.pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const MarketHomePage()),
          );
        },
      ),
    ),
    (_) => false,
  );
}

class IndiaTradingApp extends StatefulWidget {
  const IndiaTradingApp({super.key});

  @override
  State<IndiaTradingApp> createState() => _IndiaTradingAppState();
}

class _IndiaTradingAppState extends State<IndiaTradingApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLanguage.instance.addListener(_languageChanged);
    AppearanceSettings.instance.addListener(_languageChanged);
  }

  void _languageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppLanguage.instance.removeListener(_languageChanged);
    AppearanceSettings.instance.removeListener(_languageChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding must not sign the user out, clear navigation, or dispose
    // live services. Mobile operating systems may suspend networking while the
    // app is backgrounded, so reconnect and refresh once it becomes active.
    if (state == AppLifecycleState.resumed && marketSocket.hasStarted) {
      marketSocket.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: Locale(AppLanguage.instance.code),
      supportedLocales: const [Locale('en'), Locale('hi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: AppearanceSettings.instance.value == 'highContrast'
          ? AppTheme.highContrast()
          : AppTheme.light(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final content = MediaQuery(
          data: media.copyWith(
            // Prevent system accessibility scaling from making dense trading
            // controls unusable while retaining meaningful text enlargement.
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.4,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
        return ListenableBuilder(
          listenable: AppClientSettingsService.instance,
          builder: (context, _) {
            final gate = AppClientSettingsService.instance.gate;
            if (gate == AppSettingsGate.forceUpdate) {
              return const ForceUpdatePage();
            }
            if (gate == AppSettingsGate.maintenance) {
              return const MaintenancePage();
            }
            return content;
          },
        );
      },
      initialRoute: kIsWeb && Uri.base.path == '/register' ? '/register' : '/',
      routes: {
        '/': (_) => const AuthGate(),
        '/register': (_) => const RegisterPage(),
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final authService = AuthService();
  late Future<AuthSession?> sessionFuture;

  @override
  void initState() {
    super.initState();
    sessionFuture = _initializeApp();
  }

  Future<AuthSession?> _initializeApp() async {
    final results = await Future.wait<dynamic>([
      authService.restoreSession(),
      LocalDataCache.readJson(LocalDataCache.marketSnapshot),
      LocalDataCache.readJson(LocalDataCache.accountSnapshot),
      _warmApiConnection(),
      Future<void>.delayed(const Duration(milliseconds: 1400)),
    ]);
    return results.first as AuthSession?;
  }

  Future<void> _warmApiConnection() async {
    try {
      await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/health'))
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Login remains available and will show a precise network error itself.
    }
  }

  Widget _marketHome() {
    marketSocket.connect();
    return const MarketHomePage();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthSession?>(
      future: sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SplashPage(
            status: 'Checking saved session',
            detail: 'Starting the app and verifying any saved token.',
          );
        }

        if (!snapshot.hasError && snapshot.data != null) {
          return _marketHome();
        }

        return LoginPage(
          notice: snapshot.hasError
              ? 'Unable to restore your session. Check your connection and sign in.'
              : null,
          onSignedIn: (_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => _marketHome()),
            );
          },
        );
      },
    );
  }
}
