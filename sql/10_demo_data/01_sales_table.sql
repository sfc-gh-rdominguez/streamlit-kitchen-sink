/*
 * ============================================================================
 * Phase 2 · 10_demo_data/01_sales_table.sql  —  Demo data + object grants
 * ============================================================================
 *
 * A tiny sales-by-region table drives the owner's-vs-caller's-rights demo.
 * Owned by KS_APP_DEVELOPER (the dev app owner). Business roles get SELECT so
 * that, under restricted caller's rights, a viewer who holds one of those roles
 * actually possesses the SELECT privilege the app runs with on their behalf.
 *
 * (Restricted caller's rights are an INTERSECTION: the viewer must hold the
 * privilege AND the owner must hold a matching caller grant — see
 * sql/20_caller_grants/01_caller_grants.sql.)
 *
 * Idempotent.
 * ============================================================================
 */

USE ROLE KS_APP_DEVELOPER;
USE WAREHOUSE KS_WH;

CREATE TABLE IF NOT EXISTS KITCHEN_SINK_DEV.APPS.SALES_BY_REGION (
  region     VARCHAR,
  rep        VARCHAR,
  deal       VARCHAR,
  amount     NUMBER(12,2),
  closed_on  DATE
);

-- Reset + seed so re-runs are deterministic.
TRUNCATE TABLE KITCHEN_SINK_DEV.APPS.SALES_BY_REGION;
INSERT INTO KITCHEN_SINK_DEV.APPS.SALES_BY_REGION
  (region, rep, deal, amount, closed_on) VALUES
  ('EAST', 'Ada',   'Acme Corp',      120000.00, '2026-01-14'),
  ('EAST', 'Ada',   'Globex',          84000.00, '2026-02-03'),
  ('EAST', 'Ben',   'Initech',         56000.00, '2026-02-19'),
  ('WEST', 'Cleo',  'Umbrella',       210000.00, '2026-01-27'),
  ('WEST', 'Cleo',  'Soylent',         73000.00, '2026-02-11'),
  ('WEST', 'Drew',  'Hooli',          145000.00, '2026-03-02');

-- Object access for the business roles (row filtering is handled by the policy).
GRANT SELECT ON TABLE KITCHEN_SINK_DEV.APPS.SALES_BY_REGION TO ROLE KS_SALES_EAST;
GRANT SELECT ON TABLE KITCHEN_SINK_DEV.APPS.SALES_BY_REGION TO ROLE KS_SALES_WEST;
GRANT SELECT ON TABLE KITCHEN_SINK_DEV.APPS.SALES_BY_REGION TO ROLE KS_SALES_LEADERSHIP;
