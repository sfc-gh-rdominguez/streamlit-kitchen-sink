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
 * Runs entirely as the scoped CI role KS_APP_DEPLOYER (no SYSADMIN/ACCOUNTADMIN):
 * it inherits KS_APP_OWNER_PROD (to read prod), holds CREATE DATABASE/SCHEMA and
 * MANAGE CALLER GRANTS, and owns the freshly cloned objects (so it can transfer
 * ownership to the app owner role). READ SESSION is pre-granted at setup.
 *
 * A clone carries table data, the row access + masking policies (references
 * rewired to the clone's own copies), and child SELECT grants — it does NOT
 * carry ownership, container USAGE grants, or caller grants, so those are
 * (re)applied here. Safe to re-run.
 * ============================================================================
 */

USE ROLE KS_APP_DEPLOYER;
USE WAREHOUSE KS_WH;

-- 1. Zero-copy clone the data schema (reads source via inherited prod owner).
CREATE OR REPLACE SCHEMA <% target_db %>.DATA CLONE <% source_db %>.DATA;

-- 2. Re-apply container USAGE (not carried by a clone) while the deployer still
--    owns the schema. Child SELECT grants on the table travel with the clone.
GRANT USAGE ON SCHEMA <% target_db %>.DATA TO ROLE KS_SALES_EAST;
GRANT USAGE ON SCHEMA <% target_db %>.DATA TO ROLE KS_SALES_WEST;
GRANT USAGE ON SCHEMA <% target_db %>.DATA TO ROLE KS_SALES_LEADERSHIP;

-- 3. Caller grants for the app owner (deployer holds MANAGE CALLER GRANTS).
GRANT CALLER USAGE ON DATABASE <% target_db %> TO ROLE <% owner_role %>;
GRANT CALLER USAGE ON SCHEMA <% target_db %>.DATA TO ROLE <% owner_role %>;
GRANT CALLER SELECT ON TABLE <% target_db %>.DATA.SALES_BY_REGION TO ROLE <% owner_role %>;
GRANT CALLER USAGE ON WAREHOUSE KS_WH TO ROLE <% owner_role %>;

-- 4. Hand ownership of the clone to the app owner role (COPY CURRENT GRANTS
--    preserves the USAGE grants applied above and the cloned SELECT grants).
GRANT OWNERSHIP ON SCHEMA <% target_db %>.DATA
  TO ROLE <% owner_role %> COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ALL TABLES IN SCHEMA <% target_db %>.DATA
  TO ROLE <% owner_role %> COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ROW ACCESS POLICY <% target_db %>.DATA.SALES_REGION_POLICY
  TO ROLE <% owner_role %> COPY CURRENT GRANTS;
GRANT OWNERSHIP ON MASKING POLICY <% target_db %>.DATA.MASK_REP
  TO ROLE <% owner_role %> COPY CURRENT GRANTS;
