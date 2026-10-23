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

test('admin page content stays centered and uses responsive gutters', () => {
  assert.match(css, /\.ops-page-frame\s*\{[^}]*max-width:\s*1760px/s);
  assert.match(css, /\.ops-page-frame\s*\{[^}]*margin-inline:\s*auto/s);
  assert.match(css, /@media \(max-width: 1199px\)\s*\{\s*\.ops-content\s*\{\s*padding: 20px/s);
  assert.match(css, /@media \(max-width: 899px\)\s*\{[\s\S]*?\.ops-content\s*\{\s*padding: 16px/s);
  assert.match(css, /@media \(max-width: 480px\)\s*\{\s*\.ops-content\s*\{\s*padding: 12px/s);
});

test('shared headers keep titles and actions usable at narrow widths', () => {
  assert.match(css, /\.ops-title strong\s*\{[^}]*text-overflow:\s*ellipsis;[^}]*white-space:\s*nowrap/s);
  assert.match(css, /\.ops-page-header-main\s*\{[^}]*flex:\s*1 1 520px;[^}]*min-width:\s*0/s);
  assert.match(css, /\.ops-page-extra\s*\{[^}]*max-width:\s*100%/s);
  assert.match(css, /@media \(max-width: 480px\)\s*\{[\s\S]*?\.ops-role-tag\s*\{[^}]*display:\s*none/s);
  assert.match(css, /@media \(max-width:480px\)\s*\{[\s\S]*?\.ops-page-extra\s*\{[^}]*width:\s*100%;[^}]*margin-top:\s*0/s);
});

test('shared workspaces keep filters and pagination within mobile content', () => {
  assert.match(css, /\.ops-workspace\s*\{\s*min-width:\s*0/s);
  assert.match(css, /\.ops-content \.ant-table-wrapper\s*\{[^}]*max-width:\s*100%;[^}]*overflow:\s*auto/s);
  assert.match(css, /\.ops-toolbar-filters\s*\{\s*flex:\s*1 1 560px/s);
  assert.match(css, /@media \(max-width:767px\)\s*\{[\s\S]*?\.ops-toolbar-filters,[\s\S]*?\.ops-toolbar-extra\s*\{[^}]*width:\s*100%;[^}]*flex-basis:\s*100%/s);
  assert.match(css, /@media \(max-width:767px\)\s*\{[\s\S]*?\.ops-content \.ant-table-pagination\s*\{[^}]*justify-content:\s*flex-start/s);
});
