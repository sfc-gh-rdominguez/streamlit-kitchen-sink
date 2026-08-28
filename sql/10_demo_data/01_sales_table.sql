/*
 * ============================================================================
 * Phase 2 · 10_demo_data/01_sales_table.sql  —  Demo data (env-parametrized)
 * ============================================================================
 *
 * Lives in <db>.DATA. Run against an environment with:
 *   snow sql -D db=KITCHEN_SINK_PROD -D owner_role=KS_APP_OWNER_PROD -f ...
 *
 * PROD.DATA is the source of truth. DEV.DATA is a zero-copy clone of it, so in
 * normal use this DDL only runs against prod; dev is refreshed by cloning.
 *
 * Idempotent.
 * ============================================================================
 */

USE ROLE <% owner_role %>;
USE WAREHOUSE KS_WH;
USE SCHEMA <% db %>.DATA;

CREATE TABLE IF NOT EXISTS SALES_BY_REGION (
  region     VARCHAR,
  rep        VARCHAR,
  deal       VARCHAR,
  amount     NUMBER(12,2),
  closed_on  DATE
);

TRUNCATE TABLE SALES_BY_REGION;
INSERT INTO SALES_BY_REGION (region, rep, deal, amount, closed_on) VALUES
  ('EAST', 'Ada',   'Acme Corp',      120000.00, '2026-01-14'),
  ('EAST', 'Ada',   'Globex',          84000.00, '2026-02-03'),
  ('EAST', 'Ben',   'Initech',         56000.00, '2026-02-19'),
  ('WEST', 'Cleo',  'Umbrella',       210000.00, '2026-01-27'),
  ('WEST', 'Cleo',  'Soylent',         73000.00, '2026-02-11'),
  ('WEST', 'Drew',  'Hooli',          145000.00, '2026-03-02');

-- Object access for the business roles (row filtering is handled by the policy).
-- These SELECT grants survive a zero-copy clone (child-object grants are copied).
GRANT SELECT ON TABLE <% db %>.DATA.SALES_BY_REGION TO ROLE KS_SALES_EAST;
GRANT SELECT ON TABLE <% db %>.DATA.SALES_BY_REGION TO ROLE KS_SALES_WEST;
GRANT SELECT ON TABLE <% db %>.DATA.SALES_BY_REGION TO ROLE KS_SALES_LEADERSHIP;
