/*
 * ============================================================================
 * Phase 1 · 02_databases.sql  —  Dev / Prod databases and schemas
 * ============================================================================
 *
 * Two databases in one account model the promotion story (Phase 3):
 *   KITCHEN_SINK_DEV.APPS    development
 *   KITCHEN_SINK_PROD.APPS   production
 *
 * SYSADMIN owns the objects. We then hand ownership of each APPS schema to the
 * role responsible for that environment so app objects created there are owned
 * by the right functional role (not by a person).
 *
 * Idempotent: CREATE ... IF NOT EXISTS; GRANTs are no-ops if already present.
 * ============================================================================
 */

USE ROLE SYSADMIN;

-- ---------------------------------------------------------------------------
-- Databases + schemas
-- ---------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS KITCHEN_SINK_DEV
  COMMENT = 'Kitchen Sink — development environment';
CREATE DATABASE IF NOT EXISTS KITCHEN_SINK_PROD
  COMMENT = 'Kitchen Sink — production environment';

CREATE SCHEMA IF NOT EXISTS KITCHEN_SINK_DEV.APPS
  COMMENT = 'Streamlit apps + demo data (dev)';
CREATE SCHEMA IF NOT EXISTS KITCHEN_SINK_PROD.APPS
  COMMENT = 'Streamlit apps (prod)';

-- Drop the default PUBLIC schema noise is optional; we leave it in place.

-- ---------------------------------------------------------------------------
-- Environment ownership
--
-- DEV APPS  -> KS_APP_DEVELOPER  (developer owns/creates dev apps)
-- PROD APPS -> KS_APP_OWNER_PROD (prod app owned by a dedicated prod role)
--
-- REVOKE CURRENT GRANTS ... COPY CURRENT GRANTS keeps existing grants intact
-- and is safe to re-run.
-- ---------------------------------------------------------------------------
USE ROLE SECURITYADMIN;

GRANT OWNERSHIP ON SCHEMA KITCHEN_SINK_DEV.APPS
  TO ROLE KS_APP_DEVELOPER COPY CURRENT GRANTS;
GRANT OWNERSHIP ON SCHEMA KITCHEN_SINK_PROD.APPS
  TO ROLE KS_APP_OWNER_PROD COPY CURRENT GRANTS;

-- Database USAGE so roles can navigate into their schemas.
GRANT USAGE ON DATABASE KITCHEN_SINK_DEV  TO ROLE KS_APP_DEVELOPER;
GRANT USAGE ON DATABASE KITCHEN_SINK_DEV  TO ROLE KS_APP_DEPLOYER;
GRANT USAGE ON DATABASE KITCHEN_SINK_PROD TO ROLE KS_APP_OWNER_PROD;
GRANT USAGE ON DATABASE KITCHEN_SINK_PROD TO ROLE KS_APP_DEPLOYER;

-- Business/data roles need USAGE on the dev db/schema to reach the sales
-- table. The SELECT grant, the user->region mapping table, and the row access
-- policy all live in Phase 2 (sql/10_demo_data + sql/20_caller_grants),
-- alongside the objects they govern.
GRANT USAGE ON DATABASE KITCHEN_SINK_DEV TO ROLE KS_SALES_EAST;
GRANT USAGE ON DATABASE KITCHEN_SINK_DEV TO ROLE KS_SALES_WEST;
GRANT USAGE ON DATABASE KITCHEN_SINK_DEV TO ROLE KS_SALES_LEADERSHIP;
GRANT USAGE ON SCHEMA KITCHEN_SINK_DEV.APPS TO ROLE KS_SALES_EAST;
GRANT USAGE ON SCHEMA KITCHEN_SINK_DEV.APPS TO ROLE KS_SALES_WEST;
GRANT USAGE ON SCHEMA KITCHEN_SINK_DEV.APPS TO ROLE KS_SALES_LEADERSHIP;

-- The deployer needs to create Streamlit objects in both environments.
GRANT USAGE ON SCHEMA KITCHEN_SINK_DEV.APPS  TO ROLE KS_APP_DEPLOYER;
GRANT USAGE ON SCHEMA KITCHEN_SINK_PROD.APPS TO ROLE KS_APP_DEPLOYER;
GRANT CREATE STREAMLIT ON SCHEMA KITCHEN_SINK_DEV.APPS  TO ROLE KS_APP_DEPLOYER;
GRANT CREATE STREAMLIT ON SCHEMA KITCHEN_SINK_PROD.APPS TO ROLE KS_APP_DEPLOYER;
