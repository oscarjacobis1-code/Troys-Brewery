import test from 'node:test';
import assert from 'node:assert/strict';
import { calculateDisplayTotal, canTransition, normalisePhone, validateFulfilment } from '../public/js/domain.js';

test('display total includes quantity and modifiers without floating point money', () => {
  assert.equal(calculateDisplayTotal([{ unitPrice: 750, quantity: 2, modifiers: [{ price: 250 }] }]), 2000);
});

test('display total does not accept negative values', () => {
  assert.equal(calculateDisplayTotal([{ unitPrice: -100, quantity: 2, modifiers: [{ price: -5 }] }]), 0);
});

test('delivery requires an address', () => {
  assert.deepEqual(validateFulfilment({ fulfilment: 'delivery', address: '  ' }), ['A delivery address is required.']);
  assert.deepEqual(validateFulfilment({ fulfilment: 'delivery', address: 'Ogle, ECD' }), []);
});

test('pickup cannot skip preparation states', () => {
  assert.equal(canTransition('confirmed', 'delivered'), false);
  assert.equal(canTransition('confirmed', 'accepted'), true);
  assert.equal(canTransition('ready_for_pickup', 'collected'), true);
});

test('terminal orders cannot move back into production', () => {
  assert.equal(canTransition('cancelled', 'confirmed'), false);
  assert.equal(canTransition('delivered', 'preparing'), false);
});

test('delivery follows assignment and journey states', () => {
  assert.equal(canTransition('awaiting_driver', 'picked_up'), true);
  assert.equal(canTransition('picked_up', 'out_for_delivery'), true);
  assert.equal(canTransition('out_for_delivery', 'delivered'), true);
  assert.equal(canTransition('awaiting_driver', 'delivered'), false);
});

test('Guyana local numbers receive the country code', () => {
  assert.equal(normalisePhone('600-1234'), '5926001234');
  assert.equal(normalisePhone('+592 600 1234'), '5926001234');
});
