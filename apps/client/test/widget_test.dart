import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/main.dart';

void main() {
  testWidgets('Login page displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const IndiaTradingApp());

    expect(find.text('India Trading'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create New Account'), findsOneWidget);
  });
}