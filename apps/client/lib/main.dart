import 'package:flutter/material.dart';

import 'app_config.dart';
import 'models/auth_session.dart';
import 'pages/login_page.dart';
import 'pages/market_page.dart';
import 'services/auth_service.dart';
import 'services/session_expiry_service.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

class IndiaTradingApp extends StatelessWidget {
  const IndiaTradingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: AppTheme.light(),
      home: const AuthGate(),
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
    sessionFuture = authService.restoreSession();
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data != null) {
          return _marketHome();
        }

        return LoginPage(
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
