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

-- Warehouse USAGE for every role that runs queries. Build roles run the app;
-- business roles get USAGE too so you can assume them in a worksheet to test
-- the row access policy directly. KS_STREAMLIT_VIEWER does NOT get warehouse
-- USAGE: it only opens apps, which run on the app's owner-provisioned warehouse.
GRANT USAGE ON WAREHOUSE KS_WH TO ROLE KS_APP_DEVELOPER;
GRANT USAGE ON WAREHOUSE KS_WH TO ROLE KS_APP_DEPLOYER;
GRANT USAGE ON WAREHOUSE KS_WH TO ROLE KS_APP_OWNER_PROD;
GRANT USAGE ON WAREHOUSE KS_WH TO ROLE KS_SALES_EAST;
GRANT USAGE ON WAREHOUSE KS_WH TO ROLE KS_SALES_WEST;
GRANT USAGE ON WAREHOUSE KS_WH TO ROLE KS_SALES_LEADERSHIP;

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

-- ---------------------------------------------------------------------------
-- Container-runtime package resolution
--
-- A container-runtime Streamlit app must declare its dependencies in a
-- pyproject.toml, and those packages are resolved from an attached artifact
-- repository. Granting the built-in Snowflake PyPI mirror role lets the app
-- owner roles attach snowflake.snowpark.pypi_shared_repository (no external
-- access integration or internet required). The app itself is attached to the
-- repository at deploy time (see the justfile `deploy` recipe).
-- ---------------------------------------------------------------------------
GRANT DATABASE ROLE SNOWFLAKE.PYPI_REPOSITORY_USER TO ROLE KS_APP_DEVELOPER;
GRANT DATABASE ROLE SNOWFLAKE.PYPI_REPOSITORY_USER TO ROLE KS_APP_OWNER_PROD;
