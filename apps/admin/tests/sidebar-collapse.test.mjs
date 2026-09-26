import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const shell = readFileSync(new URL('../components/AdminShell.tsx', import.meta.url), 'utf8');
const css = readFileSync(new URL('../app/globals.css', import.meta.url), 'utf8');

test('sidebar persists its preference and has accessible desktop controls', () => {
  assert.match(shell, /localStorage.getItem\("hnw-sidebar-collapsed"\)/);
  assert.match(shell, /localStorage.setItem\("hnw-sidebar-collapsed", String\(next\)\)/);
  assert.match(shell, /onClick=\{toggleSidebar\}/);
  assert.match(shell, /aria-expanded=\{!collapsed\}/);
  assert.match(shell, /title: item.label/);
});

test('mobile drawer stays expanded independently of desktop preference', () => {
  assert.match(shell, /inlineCollapsed=\{!mobile && collapsed\}/);
  assert.match(shell, /open=\{mobile && drawerOpen\}/);
  assert.match(css, /ant-layout-sider-collapsed \.ant-menu-item-group-title/);
});
