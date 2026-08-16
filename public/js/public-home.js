import { api } from './api.js';
import { config, isConfigured } from './config.js';
import { formatMoney } from './domain.js';
import { escapeHtml } from './ui.js';

const target = document.querySelector('#featured-menu');
if (isConfigured()) {
  api.menu().then(menu => {
    const items = (menu?.items || menu || []).slice(0, 6);
    target.innerHTML = items.map(item => `<article class="card menu-card"><p class="eyebrow">${escapeHtml(item.category_name || 'Coffee')}</p><h3>${escapeHtml(item.name)}</h3><p class="muted">${escapeHtml(item.description || '')}</p><span class="price">From ${formatMoney(item.from_price, config.currency)}</span></article>`).join('') || '<p>No items are currently available.</p>';
  }).catch(() => { target.innerHTML = '<div class="notice error">Live menu is temporarily unavailable. Please call the store before travelling.</div>'; });
} else {
  target.innerHTML = '<div class="notice">The live menu will appear after the development Supabase project is configured.</div>';
}
