/*
 * ============================================================================
 * 25_env_refresh/clone_data.sql  —  Refresh a DATA schema by zero-copy clone
 * ============================================================================
 *
 * Generalized "data comes down" refresh, parametrized by:
 *   <% target_db %>   database whose DATA schema is (re)built   (must exist)
 *   <% source_db %>   database to clone DATA from               (source of truth)
 *   <% owner_role %>  role that should own the refreshed schema (app owner role)
 *
 * Uses:
 *   - refresh staging:  target=KITCHEN_SINK_STAGING source=KITCHEN_SINK_PROD owner=KS_APP_STAGING
 *   - PR preview:        target=KITCHEN_SINK_PR_<n>  source=KITCHEN_SINK_PROD owner=KS_APP_STAGING
 *
 * A clone carries table data, the row access + masking policies (references
 * rewired to the clone's own copies), and child SELECT grants. It does NOT
 * carry ownership, container USAGE grants, or caller grants — this script
 * re-applies those. Safe to re-run.
 * ============================================================================
 */

-- 1. Zero-copy clone the data schema (SYSADMIN can read the source + create it).
USE ROLE SYSADMIN;
CREATE OR REPLACE SCHEMA <% target_db %>.DATA CLONE <% source_db %>.DATA;

-- 2. Hand ownership of the clone to the app owner role.
USE ROLE SECURITYADMIN;
GRANT OWNERSHIP ON SCHEMA <% target_db %>.DATA
  TO ROLE <% owner_role %> COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ALL TABLES IN SCHEMA <% target_db %>.DATA
  TO ROLE <% owner_role %> COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ROW ACCESS POLICY <% target_db %>.DATA.SALES_REGION_POLICY
  TO ROLE <% owner_role %> COPY CURRENT GRANTS;
GRANT OWNERSHIP ON MASKING POLICY <% target_db %>.DATA.MASK_REP
  TO ROLE <% owner_role %> COPY CURRENT GRANTS;

-- 3. Re-apply container USAGE (not carried by a clone). Child SELECT grants on
--    the table travel with the clone, so they don't need reapplying.
GRANT USAGE ON SCHEMA <% target_db %>.DATA TO ROLE KS_SALES_EAST;
GRANT USAGE ON SCHEMA <% target_db %>.DATA TO ROLE KS_SALES_WEST;
GRANT USAGE ON SCHEMA <% target_db %>.DATA TO ROLE KS_SALES_LEADERSHIP;
GRANT USAGE ON SCHEMA <% target_db %>.DATA TO ROLE KS_APP_DEPLOYER;

-- 4. Re-apply caller grants for the app owner + ensure READ SESSION.
USE ROLE ACCOUNTADMIN;
GRANT READ SESSION ON ACCOUNT TO ROLE <% owner_role %>;
USE ROLE KS_APP_ADMIN;
GRANT CALLER USAGE ON DATABASE <% target_db %> TO ROLE <% owner_role %>;
GRANT CALLER USAGE ON SCHEMA <% target_db %>.DATA TO ROLE <% owner_role %>;
GRANT CALLER SELECT ON TABLE <% target_db %>.DATA.SALES_BY_REGION TO ROLE <% owner_role %>;
GRANT CALLER USAGE ON WAREHOUSE KS_WH TO ROLE <% owner_role %>;
