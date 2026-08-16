import { isConfigured } from './config.js';
import { clearSession, getSession, signOut } from './api.js';

export function showMessage(target, text, type = 'error') {
  const element = typeof target === 'string' ? document.querySelector(target) : target;
  if (!element) return;
  element.innerHTML = text ? `<div class="notice ${type}">${escapeHtml(text)}</div>` : '';
}

export function escapeHtml(value) {
  const node = document.createElement('span');
  node.textContent = String(value ?? '');
  return node.innerHTML;
}

export function requireConfiguration() {
  if (isConfigured()) return true;
  const lock = document.createElement('div');
  lock.className = 'setup-lock';
  lock.innerHTML = '<div><p class="eyebrow">Setup required</p><h1>Connect the development Supabase project</h1><p>This interface is intentionally locked until <code>public/config.js</code> contains a valid project URL, anon key and store ID.</p></div>';
  document.body.append(lock);
  return false;
}

export function requireTeamSession() {
  if (!requireConfiguration()) return null;
  const session = getSession();
  if (!session?.access_token) {
    window.location.replace('login.html');
    return null;
  }
  return session;
}

export function wireTeamHeader(session) {
  const identity = document.querySelector('#identity');
  if (identity) identity.textContent = session?.user?.email || 'Team member';
  document.querySelector('#logout')?.addEventListener('click', async () => {
    try { await signOut(); } finally { clearSession(); window.location.replace('login.html'); }
  });
}

export function setBusy(button, busy, busyText = 'Working…') {
  if (!button) return;
  if (busy) button.dataset.label = button.textContent;
  button.disabled = busy;
  button.textContent = busy ? busyText : (button.dataset.label || button.textContent);
}
