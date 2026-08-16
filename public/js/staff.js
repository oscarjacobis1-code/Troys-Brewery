import { api } from './api.js';
import { config } from './config.js';
import { canTransition, calculateDisplayTotal, formatMoney } from './domain.js';
import { escapeHtml, requireTeamSession, setBusy, showMessage, wireTeamHeader } from './ui.js';

const session = requireTeamSession();
if (session) initialise(session);

async function initialise(activeSession) {
  wireTeamHeader(activeSession);
  let workspace;
  let cart = [];
  let counterRequestKey = crypto.randomUUID();
  const message = document.querySelector('#message');

  async function refresh() {
    try { workspace = await api.staffWorkspace(); renderMenu(); renderBoard(); }
    catch (error) { showMessage(message, error.message); }
  }
  function renderMenu() {
    const menu = workspace?.menu || [];
    document.querySelector('#staff-menu').innerHTML = menu.map(item => `<button class="card menu-card" data-add="${item.default_variant_id}"><strong>${escapeHtml(item.name)}</strong><span class="price">${formatMoney(item.from_price, config.currency)}</span></button>`).join('');
  }
  function renderCart() {
    document.querySelector('#staff-cart').innerHTML = cart.length ? cart.map(item => `<div class="cart-row row"><span>${item.quantity}× ${escapeHtml(item.name)}</span><button class="icon-btn" data-remove="${item.variantId}" aria-label="Remove">×</button></div>`).join('') : '<p class="muted">No items added.</p>';
    document.querySelector('#staff-total').textContent = formatMoney(calculateDisplayTotal(cart), config.currency);
  }
  function renderBoard() {
    const stages = [['confirmed','New'],['accepted','Accepted'],['preparing','Preparing'],['ready_for_pickup','Ready'],['awaiting_driver','Driver needed']];
    document.querySelector('#order-board').innerHTML = stages.slice(0,3).map(([status,label], index) => `<section class="column"><h2>${label}</h2>${(workspace?.orders || []).filter(order => index === 2 ? ['preparing','ready_for_pickup','awaiting_driver'].includes(order.status) : order.status === status).map(orderCard).join('') || '<p class="muted">No orders.</p>'}</section>`).join('');
  }
  function orderCard(order) {
    const suggested = order.status === 'confirmed' ? 'accepted' : order.status === 'accepted' ? 'preparing' : order.fulfilment === 'delivery' ? 'awaiting_driver' : 'ready_for_pickup';
    const assignment=order.status==='awaiting_driver'?`<div class="field"><label for="driver-${order.id}">Assign driver</label><select id="driver-${order.id}" data-driver-select="${order.id}"><option value="">Choose driver</option>${(workspace.drivers||[]).map(driver=>`<option value="${driver.user_id}">${escapeHtml(driver.display_name)}</option>`).join('')}</select></div><button class="btn btn-primary" data-assign="${order.id}">Assign delivery</button>`:'';
    return `<article class="order-card"><div class="row"><strong>${escapeHtml(order.order_number)}</strong><span class="badge ${order.fulfilment === 'delivery' ? 'delivery' : ''}">${escapeHtml(order.fulfilment)}</span></div><p>${(order.items || []).map(item => `${item.quantity}× ${escapeHtml(item.name)}`).join('<br>')}</p>${canTransition(order.status,suggested) ? `<button class="btn btn-dark" data-transition="${order.id}" data-next="${suggested}">Move to ${suggested.replaceAll('_',' ')}</button>` : ''}${assignment}</article>`;
  }
  document.querySelector('#staff-menu').addEventListener('click', event => {
    const button = event.target.closest('[data-add]'); if (!button) return;
    const item = workspace.menu.find(candidate => candidate.default_variant_id === button.dataset.add);
    const existing = cart.find(candidate => candidate.variantId === button.dataset.add);
    if (existing) existing.quantity += 1; else cart.push({ variantId: button.dataset.add, name: item.name, unitPrice: item.from_price, quantity: 1, modifiers: [] }); counterRequestKey=crypto.randomUUID();
    renderCart();
  });
  document.querySelector('#staff-cart').addEventListener('click', event => { const button = event.target.closest('[data-remove]'); if (!button) return; cart = cart.filter(item => item.variantId !== button.dataset.remove); counterRequestKey=crypto.randomUUID(); renderCart(); });
  document.querySelector('#order-board').addEventListener('click', async event => { const transition=event.target.closest('[data-transition]');const assignment=event.target.closest('[data-assign]');const button=transition||assignment;if(!button)return;setBusy(button,true);try{if(transition)await api.transitionOrder(transition.dataset.transition,transition.dataset.next);else{const driver=document.querySelector(`[data-driver-select="${assignment.dataset.assign}"]`).value;if(!driver)throw new Error('Choose a driver.');await api.assignDelivery(assignment.dataset.assign,driver);}await refresh();}catch(error){showMessage(message,error.message);}finally{setBusy(button,false);} });
  document.querySelector('#submit-counter').addEventListener('click', async event => {
    if (!cart.length) return showMessage(message,'Add at least one item.');
    setBusy(event.currentTarget,true,'Creating…');
    try { const method=document.querySelector('#payment-method').value; const reference=document.querySelector('#payment-reference').value.trim(); if(method!=='cash'&&!reference) throw new Error('Enter the MMG or card payment reference.'); await api.createCounterOrder({ idempotency_key:counterRequestKey, customer:{name:document.querySelector('#customer-name').value||'Guest'}, fulfilment:document.querySelector('#counter-fulfilment').value, payment_method:method, provider_reference:reference||null, items:cart.map(item=>({variant_id:item.variantId,quantity:item.quantity,modifier_option_ids:[]})) }); cart=[];counterRequestKey=crypto.randomUUID();renderCart();await refresh();showMessage(message,'Order created and priced by the server.','success'); }
    catch(error){showMessage(message,error.message);} finally{setBusy(event.currentTarget,false);}
  });
  document.querySelector('#payment-method').addEventListener('change',event=>document.querySelector('#payment-reference-field').classList.toggle('hidden',event.target.value==='cash'));
  await refresh(); renderCart(); setInterval(()=>{api.heartbeat().catch(()=>undefined);refresh();},5000);
}
