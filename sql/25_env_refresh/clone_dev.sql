/*
 * ============================================================================
 * 25_env_refresh/clone_dev.sql  —  Refresh DEV.DATA from PROD.DATA (zero-copy)
 * ============================================================================
 *
 * "Data comes down": DEV.DATA is a zero-copy clone of the PROD.DATA source of
 * truth — instant, near-zero storage, and it carries the table data, the row
 * access + masking policies (with references rewired to the dev copies), and
 * the child-object SELECT grants.
 *
 * A clone does NOT carry: container (schema) USAGE grants, object ownership, or
 * caller grants. This script re-applies those after the clone.
 *
 * Safe to re-run: CREATE OR REPLACE rebuilds DEV.DATA from the current prod
 * state. (It does not touch DEV.APPS, so the deployed app is unaffected.)
 * ============================================================================
 */

-- 1. Zero-copy clone the data schema (SYSADMIN can read prod + create in dev).
USE ROLE SYSADMIN;
CREATE OR REPLACE SCHEMA KITCHEN_SINK_DEV.DATA CLONE KITCHEN_SINK_PROD.DATA;

-- 2. Hand ownership of the clone back to the dev owner role.
USE ROLE SECURITYADMIN;
GRANT OWNERSHIP ON SCHEMA KITCHEN_SINK_DEV.DATA
  TO ROLE KS_APP_DEVELOPER COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ALL TABLES IN SCHEMA KITCHEN_SINK_DEV.DATA
  TO ROLE KS_APP_DEVELOPER COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ROW ACCESS POLICY KITCHEN_SINK_DEV.DATA.SALES_REGION_POLICY
  TO ROLE KS_APP_DEVELOPER COPY CURRENT GRANTS;
GRANT OWNERSHIP ON MASKING POLICY KITCHEN_SINK_DEV.DATA.MASK_REP
  TO ROLE KS_APP_DEVELOPER COPY CURRENT GRANTS;

-- 3. Re-apply container USAGE (not carried by a clone). Child SELECT grants on
--    the table are carried, so they don't need reapplying.
GRANT USAGE ON SCHEMA KITCHEN_SINK_DEV.DATA TO ROLE KS_SALES_EAST;
GRANT USAGE ON SCHEMA KITCHEN_SINK_DEV.DATA TO ROLE KS_SALES_WEST;
GRANT USAGE ON SCHEMA KITCHEN_SINK_DEV.DATA TO ROLE KS_SALES_LEADERSHIP;
GRANT USAGE ON SCHEMA KITCHEN_SINK_DEV.DATA TO ROLE KS_APP_DEPLOYER;

-- 4. Re-apply caller grants for the dev app owner + ensure READ SESSION.
USE ROLE ACCOUNTADMIN;
GRANT READ SESSION ON ACCOUNT TO ROLE KS_APP_DEVELOPER;
USE ROLE KS_APP_ADMIN;
GRANT CALLER USAGE ON DATABASE KITCHEN_SINK_DEV TO ROLE KS_APP_DEVELOPER;
GRANT CALLER USAGE ON SCHEMA KITCHEN_SINK_DEV.DATA TO ROLE KS_APP_DEVELOPER;
GRANT CALLER SELECT ON TABLE KITCHEN_SINK_DEV.DATA.SALES_BY_REGION TO ROLE KS_APP_DEVELOPER;
GRANT CALLER USAGE ON WAREHOUSE KS_WH TO ROLE KS_APP_DEVELOPER;
