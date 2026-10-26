import assert from 'node:assert/strict';
import test from 'node:test';

import { inspectCustomerSource } from '../check-client-information-boundary.mjs';

test('customer source scanner reports internal implementation copy', () => {
  const findings = inspectCustomerSource(`
    const Text('Production API: https://api.internal/v1');
    const Text('PostgreSQL column available_cash failed');
    const Text('Role: SUPER_ADMIN');
    const Text('Raw provider response: $providerBody');
  `, 'lib/pages/example.dart');

  assert.deepEqual(
    findings.map((finding) => finding.rule),
    [
      'network-address',
      'environment-detail',
      'database-detail',
      'internal-role',
      'raw-provider-detail',
    ],
  );
});

test('ordinary customer and narrowly approved legal copy remain allowed', () => {
  assert.deepEqual(
    inspectCustomerSource(
      `const AppText('Your order is under review. Contact Customer Support if you need help.');`,
      'lib/pages/orders_page.dart',
    ),
    [],
  );
  assert.deepEqual(
    inspectCustomerSource(
      `const _LegalSection('Security', 'We use cloud and security providers.');`,
      'lib/pages/legal_page_content.dart',
    ),
    [],
  );
});
