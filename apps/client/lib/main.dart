import 'package:flutter/material.dart';

import 'app_config.dart';
import 'models/auth_session.dart';
import 'pages/login_page.dart';
import 'pages/market_page.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const IndiaTradingApp());
}

class IndiaTradingApp extends StatelessWidget {
  const IndiaTradingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
          return const MarketHomePage();
        }

        return LoginPage(
          onSignedIn: (_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const MarketHomePage()),
            );
          },
        );
      },
    );
  }
}
