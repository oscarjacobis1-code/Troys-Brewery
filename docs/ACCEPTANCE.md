# Launch acceptance criteria

The system must not be connected to real payments or treated as production-ready until every item below is verified in a staging project.

## Security

- [ ] Individual accounts exist; no shared staff credentials.
- [ ] Every public table has RLS enabled and pgTAP security tests pass.
- [ ] Anonymous users cannot access staff, driver, payment, inventory or reporting functions.
- [ ] Drivers can retrieve only deliveries assigned to their own user ID.
- [ ] Prices and totals are recalculated in PostgreSQL from active menu records.
- [ ] The browser bundle contains no service key, password or payment secret.
- [ ] Rate limiting and bot protection are enabled for public ordering.

## Ordering and payment

- [ ] Duplicate submissions are idempotent and cannot double-charge or double-deduct stock.
- [ ] MMG/card payments are confirmed by a trusted server callback or authorised staff confirmation—not a browser selection alone.
- [ ] Failed and abandoned payments do not count as revenue.
- [ ] Refunds, cancellations and partial refunds are tested and audited.
- [ ] Pickup, dine-in and delivery have separate valid status paths.
- [ ] Store hours, unavailable products, delivery minimum and delivery fee are enforced server-side.

## Inventory

- [ ] Every sellable variant has a reviewed recipe.
- [ ] Two simultaneous purchases cannot make stock negative.
- [ ] Cancellation/refund stock policy is explicitly configured.
- [ ] Restocks, waste, staff use and physical-count adjustments create movements with an actor and reason.
- [ ] Expected stock and physical stock variance is visible to management.

## Operations

- [ ] Counter, preparation board, admin and driver devices see the same staging order.
- [ ] Driver assignment, pickup, en-route, delivery and failed-delivery scenarios pass.
- [ ] Session presence expires after missed heartbeats and records logout time.
- [ ] Thermal printer behaviour is tested on the actual tablet, browser and printer model.
- [ ] Backups and restore procedures are tested.

## Business sign-off

- [ ] Owner approves menu, sizes, modifiers, recipes, prices and taxes.
- [ ] Owner approves service area, delivery fee, minimum order and delivery promise.
- [ ] Owner approves who may discount, void, refund, adjust stock and view revenue.
- [ ] Privacy notice and customer-data retention period are approved.
