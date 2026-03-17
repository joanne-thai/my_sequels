# QR Restaurant MySQL Project

Production-oriented MySQL 8 project for QR-based table ordering and payment processing in a large restaurant operation.

## What This Includes

- Normalised schema for branches, tables, QR sessions, menu, orders, order items, payments, refunds, staff, and audit events.
- Integrity safeguards with primary/foreign keys, uniqueness, checks, indexes, and strict SQL mode.
- Stored procedures and triggers for:
  - automatic order line pricing/tax calculation,
  - automatic order total recalculation,
  - automatic order completion update based on successful payment capture.
- Transaction-safe seed loading:
  - seed script runs inside a guarded transaction with automatic `ROLLBACK` on exception.
  - successful run ends with `COMMIT`.
- Realistic Australian mock dataset sized for multi-branch operations.
- Analytics views and prebuilt insight queries for operations, finance, and menu engineering.

## Project Structure

- `setup.sql`: one-command bootstrap script.
- `sql/01_schema.sql`: database and table DDL.
- `sql/02_routines_and_triggers.sql`: procedures + triggers.
- `sql/03_seed_mock_data.sql`: deterministic mock data.
- `sql/04_analytics_views.sql`: reusable KPI/analytics views.
- `sql/05_analytics_queries.sql`: ready-to-run business insight queries.

## Prerequisites

- MySQL 8.0+
- User account with permission to create databases, tables, routines, and triggers.

## Quick Start

Run from this directory:

```bash
mysql -u <user> -p < setup.sql
```

Then run analytics query pack:

```bash
mysql -u <user> -p qr_restaurant_mysql < sql/05_analytics_queries.sql
```

## Core Data Model Notes

- `qr_sessions` tracks every table QR scan session and its lifecycle.
- `orders` is linked to sessions + tables + branches for complete operational traceability.
- `order_items` stores immutable unit price/tax at purchase time for accounting correctness.
- `payments` supports multiple methods/providers and refund scenarios.
- `audit_events` stores structured JSON for operational auditing.

## Transaction Behaviour

- `sql/03_seed_mock_data.sql` is atomic at the script level: all seed DML commits together, or rolls back on failure.
- `sql/01_schema.sql` includes explicit transaction boundaries, but MySQL DDL (`CREATE TABLE`, `CREATE DATABASE`) still uses implicit commits by engine design.

## Operational Analytics Included

- Daily branch-level sales, cancellation, ticket size, and payment issue rates.
- Hourly QR demand and order value (peak windows).
- Menu performance with revenue mix and rank per branch.
- Table turnover and revenue per session.
- Payment funnel quality by method/provider and failure rates.

## Production Hardening Suggestions

- Add role-based DB users (`app_rw`, `analytics_ro`) and grant least privilege.
- Rotate QR tokens periodically and store a token history table if needed.
- Add partitioning for high-volume `orders`, `order_items`, and `payments` (for multi-year retention).
- Create scheduled archival and aggregation jobs for long-term analytics efficiency.
- Integrate with migration tooling (`Flyway`/`Liquibase`) for CI/CD-controlled releases.
