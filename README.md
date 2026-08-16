# Troy's Brewery Operations Platform

Production foundation for customer ordering, counter sales, preparation, delivery and administration.

## Principles

- PostgreSQL/Supabase is the single source of truth.
- The browser never decides prices, payment success or stock deductions.
- Every staff member has an individual account and role.
- Drivers can read only deliveries assigned to them.
- Financial and inventory mutations are transactional and audited.
- Automated checks block secrets, demo passwords and browser-local business data.

## Local setup

1. Create a Supabase project.
2. Run `supabase/migrations/001_initial.sql` in a development project.
3. Copy `public/config.example.js` to `public/config.js` and add the project URL and anon key. The anon key is safe for the browser when RLS is enabled; never use the service-role key here.
4. Serve `public/` with any static server. For example: `npx serve public`.
5. Run `npm test` before every commit.

The interface remains in setup mode until valid Supabase configuration is supplied.

## Release workflow

`main` is deployable. Changes are developed on feature branches and merged only when the `quality-gate` workflow passes.

## Initial roles

- `owner`, `admin`, `manager`: reporting and operational control
- `cashier`: create counter orders and record permitted payments
- `barista`: preparation board and allowed status transitions
- `dispatcher`: assign and monitor delivery work
- `driver`: assigned deliveries only

See `docs/ACCEPTANCE.md` for the launch criteria.
