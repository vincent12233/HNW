import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/ipo.dart';

void main() {
  group('IpoApplication.fromApiJson debt', () {
    Map<String, dynamic> base({
      String paymentStatus = 'PENDING',
      Map<String, dynamic>? debt,
    }) {
      return {
        'id': 'app-1',
        'status': 'ALLOTTED',
        'paymentStatus': paymentStatus,
        'allocatedQuantity': 10,
        'allocatedPrice': '10.00',
        'allocatedAmount': '100.00',
        'debt': debt,
        'ipo': {
          'id': 'ipo-1',
          'companyName': 'Acme',
          'symbol': 'ACM',
          'issuePrice': '10.00',
        },
      };
    }

    test('open debt sets remaining and needsSubscription', () {
      final app = IpoApplication.fromApiJson(
        base(
          debt: {'amount': '100.00', 'paidAmount': '0.00', 'status': 'OPEN'},
        ),
      );
      expect(app.status, IpoApplicationStatus.allocated);
      expect(app.remainingAmount, 100);
      expect(app.needsSubscription, isTrue);
    });

    test('partial debt reduces remaining', () {
      final app = IpoApplication.fromApiJson(
        base(
          debt: {
            'amount': '100.00',
            'paidAmount': '40.00',
            'status': 'PARTIAL',
          },
        ),
      );
      expect(app.remainingAmount, 60);
      expect(app.needsSubscription, isTrue);
    });

    test('paid debt or paymentStatus PAID clears remaining', () {
      final paidStatus = IpoApplication.fromApiJson(
        base(paymentStatus: 'PAID', debt: null),
      );
      expect(paidStatus.status, IpoApplicationStatus.completed);
      expect(paidStatus.remainingAmount, 0);
      expect(paidStatus.needsSubscription, isFalse);

      final paidDebt = IpoApplication.fromApiJson(
        base(
          paymentStatus: 'PAID',
          debt: {'amount': '100.00', 'paidAmount': '100.00', 'status': 'PAID'},
        ),
      );
      expect(paidDebt.remainingAmount, 0);
      expect(paidDebt.needsSubscription, isFalse);
    });

    test('missing debt without PAID shows zero remaining', () {
      final app = IpoApplication.fromApiJson(base(debt: null));
      expect(app.status, IpoApplicationStatus.allocated);
      expect(app.remainingAmount, 0);
      expect(app.needsSubscription, isFalse);
    });
  });
}
