/*
 * ============================================================================
 * Phase 2 · 10_demo_data/02_user_region_map.sql  —  Entitlements (parametrized)
 * ============================================================================
 *
 * Lives in <db>.DATA. The row access policy joins CURRENT_USER() to this table.
 * Seeded with the operator mapped to EAST so the caller's-rights side of the app
 * filters to one region. region = 'ALL' sees everything.
 *
 * Idempotent.
 * ============================================================================
 */

USE ROLE <% owner_role %>;
USE WAREHOUSE KS_WH;
USE SCHEMA <% db %>.DATA;

CREATE TABLE IF NOT EXISTS USER_REGION_MAP (
  username  VARCHAR,   -- matches CURRENT_USER()
  region    VARCHAR    -- 'EAST' | 'WEST' | 'ALL'
);

TRUNCATE TABLE USER_REGION_MAP;
INSERT INTO USER_REGION_MAP (username, region)
SELECT CURRENT_USER(), 'EAST';
-- Add real viewers here (or in the cloned dev copy):
-- INSERT INTO USER_REGION_MAP VALUES ('ALICE', 'WEST'), ('BOSS', 'ALL');
