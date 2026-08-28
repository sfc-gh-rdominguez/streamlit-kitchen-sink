/*
 * ============================================================================
 * Phase 2 · 10_demo_data/02_user_region_map.sql  —  User -> region entitlements
 * ============================================================================
 *
 * The row access policy keys on CURRENT_USER() joined to this table, rather
 * than on role. Keying on the user is robust to which role a viewer has active
 * under restricted caller's rights (which uses the viewer's DEFAULT role unless
 * they run USE SECONDARY ROLES).
 *
 *   region = 'ALL'  ->  the user sees every region.
 *
 * Seeded with the current operator mapped to EAST so you can watch the
 * caller's-rights column filter to a single region while the owner's-rights
 * column shows everything. Edit these rows (or add real users) to taste.
 *
 * Idempotent.
 * ============================================================================
 */

USE ROLE KS_APP_DEVELOPER;
USE WAREHOUSE KS_WH;

CREATE TABLE IF NOT EXISTS KITCHEN_SINK_DEV.APPS.USER_REGION_MAP (
  username  VARCHAR,   -- matches CURRENT_USER()
  region    VARCHAR    -- 'EAST' | 'WEST' | 'ALL'
);

TRUNCATE TABLE KITCHEN_SINK_DEV.APPS.USER_REGION_MAP;
INSERT INTO KITCHEN_SINK_DEV.APPS.USER_REGION_MAP (username, region)
SELECT CURRENT_USER(), 'EAST';
-- Example additional entitlements (uncomment / adjust for real demo users):
-- INSERT INTO KITCHEN_SINK_DEV.APPS.USER_REGION_MAP VALUES ('KS_DEMO_WEST', 'WEST');
-- INSERT INTO KITCHEN_SINK_DEV.APPS.USER_REGION_MAP VALUES ('KS_DEMO_LEAD', 'ALL');
