export const ORDER_STATUSES = Object.freeze([
  'pending_payment', 'confirmed', 'accepted', 'preparing', 'ready_for_pickup',
  'awaiting_driver', 'picked_up', 'out_for_delivery', 'collected', 'delivered',
  'cancelled', 'refunded', 'failed_delivery'
]);

export const STATUS_TRANSITIONS = Object.freeze({
  pending_payment: ['confirmed', 'cancelled'],
  confirmed: ['accepted', 'cancelled'],
  accepted: ['preparing', 'cancelled'],
  preparing: ['ready_for_pickup', 'awaiting_driver', 'cancelled'],
  ready_for_pickup: ['collected', 'cancelled'],
  awaiting_driver: ['picked_up', 'cancelled'],
  picked_up: ['out_for_delivery', 'failed_delivery'],
  out_for_delivery: ['delivered', 'failed_delivery'],
  failed_delivery: ['awaiting_driver', 'cancelled'],
  collected: ['refunded'],
  delivered: ['refunded'],
  cancelled: [],
  refunded: []
});

export function canTransition(from, to) {
  return Boolean(STATUS_TRANSITIONS[from]?.includes(to));
}

export function validateFulfilment({ fulfilment, address, requestedFor }) {
  const errors = [];
  if (!['pickup', 'delivery', 'dine_in'].includes(fulfilment)) errors.push('Choose pickup, delivery or dine-in.');
  if (fulfilment === 'delivery' && !String(address || '').trim()) errors.push('A delivery address is required.');
  if (requestedFor && Number.isNaN(Date.parse(requestedFor))) errors.push('Requested time is invalid.');
  return errors;
}

export function calculateDisplayTotal(items) {
  return items.reduce((sum, item) => {
    const quantity = Math.max(0, Number(item.quantity) || 0);
    const base = Math.max(0, Number(item.unitPrice) || 0);
    const modifiers = (item.modifiers || []).reduce((subtotal, modifier) => subtotal + Math.max(0, Number(modifier.price) || 0), 0);
    return sum + ((base + modifiers) * quantity);
  }, 0);
}

export function formatMoney(minorUnits, currency = 'GYD') {
  return new Intl.NumberFormat('en-GY', { style: 'currency', currency, maximumFractionDigits: 0 }).format(Number(minorUnits || 0));
}

export function normalisePhone(value) {
  const digits = String(value || '').replace(/\D/g, '');
  if (digits.length === 7) return `592${digits}`;
  return digits;
}
