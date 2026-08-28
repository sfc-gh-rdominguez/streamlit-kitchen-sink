/*
 * ============================================================================
 * Phase 1 · 03_warehouse_and_pool.sql  —  Warehouse + compute pool grants
 * ============================================================================
 *
 * - KS_WH: a small shared query warehouse for the apps' SQL.
 * - SYSTEM_COMPUTE_POOL_CPU: the account-default Streamlit compute pool used by
 *   the container runtime (required for restricted caller's rights in Phase 2).
 *
 * Compute pools are account-level; granting USAGE requires ACCOUNTADMIN (or a
 * role with MANAGE GRANTS). Warehouse grants are done by its SYSADMIN owner.
 *
 * Idempotent: CREATE ... IF NOT EXISTS; GRANTs are no-ops if already present.
 * ============================================================================
 */

-- ---------------------------------------------------------------------------
-- Warehouse (SYSADMIN owns it)
-- ---------------------------------------------------------------------------
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS KS_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Kitchen Sink — shared query warehouse for Streamlit apps';

-- Warehouse USAGE for every role that runs queries (developer, deployer,
-- prod owner, and all viewers). OPERATE lets a role resume/suspend if needed.
GRANT USAGE ON WAREHOUSE KS_WH TO ROLE KS_APP_DEVELOPER;
GRANT USAGE ON WAREHOUSE KS_WH TO ROLE KS_APP_DEPLOYER;
GRANT USAGE ON WAREHOUSE KS_WH TO ROLE KS_APP_OWNER_PROD;
GRANT USAGE ON WAREHOUSE KS_WH TO ROLE KS_VIEWER_EAST;
GRANT USAGE ON WAREHOUSE KS_WH TO ROLE KS_VIEWER_WEST;
GRANT USAGE ON WAREHOUSE KS_WH TO ROLE KS_VIEWER_ALL;

-- ---------------------------------------------------------------------------
-- Compute pool USAGE (ACCOUNTADMIN grants on the system pool)
--
-- The container runtime schedules the app on this pool. Roles that CREATE or
-- OWN a container-runtime Streamlit need USAGE on the pool.
-- ---------------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

GRANT USAGE ON COMPUTE POOL SYSTEM_COMPUTE_POOL_CPU TO ROLE KS_APP_DEVELOPER;
GRANT USAGE ON COMPUTE POOL SYSTEM_COMPUTE_POOL_CPU TO ROLE KS_APP_DEPLOYER;
GRANT USAGE ON COMPUTE POOL SYSTEM_COMPUTE_POOL_CPU TO ROLE KS_APP_OWNER_PROD;
