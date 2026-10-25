import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const css = readFileSync(new URL('../app/globals.css', import.meta.url), 'utf8');

test('admin visual tokens retain an 8px rhythm and accessible controls', () => {
  assert.match(css, /--space-1:\s*4px/);
  assert.match(css, /--space-2:\s*8px/);
  assert.match(css, /--space-4:\s*16px/);
  assert.match(css, /--control-min-height:\s*44px/);
  assert.match(css, /outline:\s*3px solid var\(--focus-ring\)/);
});

test('admin layout supports target viewports and reduced motion', () => {
  assert.match(css, /@media \(max-width: 1199px\)/);
  assert.match(css, /@media \(max-width: 899px\)/);
  assert.match(css, /@media \(max-width: 480px\)/);
  assert.match(css, /prefers-reduced-motion: reduce/);
  assert.match(css, /overflow-wrap:anywhere/);
});
