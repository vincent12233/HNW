import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');

test('SaleSmartly owns chat and the standalone internal console is retired', () => {
  assert.equal(existsSync(new URL('../app/support-console/page.tsx', import.meta.url)), false);
  assert.equal(existsSync(new URL('../components/RecoveryInbox.tsx', import.meta.url)), false);
  const shell = read('../components/AdminShell.tsx');
  assert.doesNotMatch(shell, /\/support-console|客服会话台/);
});

test('account recovery remains a narrow audited operator action', () => {
  const page = read('../app/operator-console/page.tsx');
  const action = read('../components/AccountRecoveryAction.tsx');
  assert.match(page, /AccountRecoveryAction/);
  assert.match(action, /SaleSmartly interaction reference/i);
  assert.match(action, /identityVerified/);
  assert.match(action, /\/support\/recovery\/\$\{selected\}\/issue/);
  assert.doesNotMatch(action, /messages|chat history|send reply/i);
});
