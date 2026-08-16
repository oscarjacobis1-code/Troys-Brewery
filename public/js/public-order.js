import { api } from './api.js';
import { config } from './config.js';
import { calculateDisplayTotal, formatMoney, normalisePhone, validateFulfilment } from './domain.js';
import { escapeHtml, requireConfiguration, setBusy, showMessage } from './ui.js';

if (requireConfiguration()) initialise();

async function initialise() {
  const menuElement = document.querySelector('#menu');
  const cartElement = document.querySelector('#cart');
  const fulfilment = document.querySelector('#fulfilment');
  const addressField = document.querySelector('#address-field');
  const submit = document.querySelector('#place-order');
  let cart = [];
  let menu = [];
  let checkoutKey = crypto.randomUUID();

  fulfilment.addEventListener('change', () => addressField.classList.toggle('hidden', fulfilment.value !== 'delivery'));

  try {
    const response = await api.menu();
    menu = response?.items || response || [];
    menuElement.innerHTML = menu.map(item => `<article class="card menu-card"><p class="eyebrow">${escapeHtml(item.category_name || 'Coffee')}</p><h3>${escapeHtml(item.name)}</h3><p class="muted">${escapeHtml(item.description || '')}</p><span class="price">${formatMoney(item.from_price, config.currency)}</span><button class="btn btn-dark" data-add="${item.default_variant_id}">Add</button></article>`).join('');
  } catch (error) {
    showMessage('#message', error.message);
    return;
  }

  menuElement.addEventListener('click', event => {
    const button = event.target.closest('[data-add]');
    if (!button) return;
    const item = menu.find(candidate => candidate.default_variant_id === button.dataset.add);
    const existing = cart.find(candidate => candidate.variantId === button.dataset.add);
    if (existing) existing.quantity += 1;
    else cart.push({ variantId: button.dataset.add, name: item.name, unitPrice: item.from_price, quantity: 1, modifiers: [] });
    checkoutKey = crypto.randomUUID();
    renderCart();
  });

  cartElement.addEventListener('click', event => {
    const button = event.target.closest('[data-cart]');
    if (!button) return;
    const item = cart.find(candidate => candidate.variantId === button.dataset.id);
    if (!item) return;
    item.quantity += button.dataset.cart === 'plus' ? 1 : -1;
    cart = cart.filter(candidate => candidate.quantity > 0);
    checkoutKey = crypto.randomUUID();
    renderCart();
  });

  function renderCart() {
    cartElement.innerHTML = cart.length ? cart.map(item => `<div class="cart-row"><div class="row"><strong>${escapeHtml(item.name)}</strong><span>${formatMoney(item.unitPrice * item.quantity, config.currency)}</span></div><div class="qty"><button class="icon-btn" data-cart="minus" data-id="${item.variantId}" aria-label="Remove one">−</button><span>${item.quantity}</span><button class="icon-btn" data-cart="plus" data-id="${item.variantId}" aria-label="Add one">+</button></div></div>`).join('') : '<p class="muted">Your order is empty.</p>';
    document.querySelector('#total').textContent = formatMoney(calculateDisplayTotal(cart), config.currency);
  }

  document.querySelector('#checkout').addEventListener('submit', async event => {
    event.preventDefault();
    if (!cart.length) return showMessage('#message', 'Add at least one item.');
    const form = new FormData(event.currentTarget);
    const fulfilmentData = { fulfilment: form.get('fulfilment'), address: form.get('address'), requestedFor: form.get('requestedFor') };
    const errors = validateFulfilment(fulfilmentData);
    if (normalisePhone(form.get('phone')).length < 10) errors.push('Enter a valid telephone number.');
    if (errors.length) return showMessage('#message', errors.join(' '));
    setBusy(submit, true, 'Placing order…');
    try {
      const result = await api.createOnlineOrder({
        idempotency_key: checkoutKey,
        customer: { name: form.get('name'), phone: normalisePhone(form.get('phone')) },
        fulfilment: form.get('fulfilment'), address: form.get('address') || null,
        requested_for: form.get('requestedFor') ? new Date(form.get('requestedFor')).toISOString() : null,
        notes: form.get('notes') || null,
        items: cart.map(item => ({ variant_id: item.variantId, quantity: item.quantity, modifier_option_ids: [] }))
      });
      cart = []; checkoutKey = crypto.randomUUID(); renderCart(); event.currentTarget.reset();
      showMessage('#message', `Order ${result.order_number} received. Save tracking code ${result.tracking_token}.`, 'success');
    } catch (error) { showMessage('#message', error.message); }
    finally { setBusy(submit, false); }
  });
  renderCart();
}
