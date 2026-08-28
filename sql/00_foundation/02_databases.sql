/*
 * ============================================================================
 * Phase 1 · 02_databases.sql  —  Dev / Prod databases and schemas
 * ============================================================================
 *
 * Two databases model the environments; each has two schemas with different
 * lifecycles:
 *
 *   <db>.DATA   business data + governance (table, entitlement map, policies).
 *              PROD.DATA is the source of truth, built by the data DDL.
 *              DEV.DATA is a zero-copy clone of PROD.DATA (see the clone recipe).
 *   <db>.APPS   the Streamlit app object. Promoted dev -> prod by CI/CD, never
 *              cloned (so its ownership stays aligned with the policies).
 *
 * "Code goes up, data comes down": the app promotes dev -> prod; data clones
 * prod -> dev.
 *
 * SYSADMIN owns the objects, then hands each schema to the role responsible for
 * that environment. Idempotent.
 * ============================================================================
 */

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS KITCHEN_SINK_STAGING  COMMENT = 'Kitchen Sink — development';
CREATE DATABASE IF NOT EXISTS KITCHEN_SINK_PROD COMMENT = 'Kitchen Sink — production';

CREATE SCHEMA IF NOT EXISTS KITCHEN_SINK_STAGING.DATA  COMMENT = 'Business data + governance (dev; cloned from prod)';
CREATE SCHEMA IF NOT EXISTS KITCHEN_SINK_STAGING.APPS  COMMENT = 'Streamlit app (dev)';
CREATE SCHEMA IF NOT EXISTS KITCHEN_SINK_PROD.DATA COMMENT = 'Business data + governance (prod; source of truth)';
CREATE SCHEMA IF NOT EXISTS KITCHEN_SINK_PROD.APPS COMMENT = 'Streamlit app (prod)';

-- ---------------------------------------------------------------------------
-- Ownership follows the environment (SECURITYADMIN manages grants)
-- ---------------------------------------------------------------------------
USE ROLE SECURITYADMIN;

GRANT OWNERSHIP ON SCHEMA KITCHEN_SINK_STAGING.DATA  TO ROLE KS_APP_STAGING  COPY CURRENT GRANTS;
GRANT OWNERSHIP ON SCHEMA KITCHEN_SINK_STAGING.APPS  TO ROLE KS_APP_STAGING  COPY CURRENT GRANTS;
GRANT OWNERSHIP ON SCHEMA KITCHEN_SINK_PROD.DATA TO ROLE KS_APP_OWNER_PROD COPY CURRENT GRANTS;
GRANT OWNERSHIP ON SCHEMA KITCHEN_SINK_PROD.APPS TO ROLE KS_APP_OWNER_PROD COPY CURRENT GRANTS;

-- ---------------------------------------------------------------------------
-- Database USAGE
-- ---------------------------------------------------------------------------
-- Env owners + the CI deployer
GRANT USAGE ON DATABASE KITCHEN_SINK_STAGING  TO ROLE KS_APP_STAGING;
GRANT USAGE ON DATABASE KITCHEN_SINK_STAGING  TO ROLE KS_APP_DEPLOYER;
GRANT USAGE ON DATABASE KITCHEN_SINK_PROD TO ROLE KS_APP_OWNER_PROD;
GRANT USAGE ON DATABASE KITCHEN_SINK_PROD TO ROLE KS_APP_DEPLOYER;
-- Business roles + the broad viewer role reach both environments
GRANT USAGE ON DATABASE KITCHEN_SINK_STAGING  TO ROLE KS_SALES_EAST;
GRANT USAGE ON DATABASE KITCHEN_SINK_STAGING  TO ROLE KS_SALES_WEST;
GRANT USAGE ON DATABASE KITCHEN_SINK_STAGING  TO ROLE KS_SALES_LEADERSHIP;
GRANT USAGE ON DATABASE KITCHEN_SINK_STAGING  TO ROLE KS_STREAMLIT_VIEWER;
GRANT USAGE ON DATABASE KITCHEN_SINK_PROD TO ROLE KS_SALES_EAST;
GRANT USAGE ON DATABASE KITCHEN_SINK_PROD TO ROLE KS_SALES_WEST;
GRANT USAGE ON DATABASE KITCHEN_SINK_PROD TO ROLE KS_SALES_LEADERSHIP;
GRANT USAGE ON DATABASE KITCHEN_SINK_PROD TO ROLE KS_STREAMLIT_VIEWER;

-- ---------------------------------------------------------------------------
-- DATA schema USAGE — business roles hold object access here; the row access
-- policy governs which rows they actually see. (SELECT on the table is granted
-- by the data DDL.) Container grants do NOT survive a clone, so the clone
-- recipe re-applies the DEV.DATA grants after refreshing it from prod.
-- ---------------------------------------------------------------------------
GRANT USAGE ON SCHEMA KITCHEN_SINK_STAGING.DATA  TO ROLE KS_SALES_EAST;
GRANT USAGE ON SCHEMA KITCHEN_SINK_STAGING.DATA  TO ROLE KS_SALES_WEST;
GRANT USAGE ON SCHEMA KITCHEN_SINK_STAGING.DATA  TO ROLE KS_SALES_LEADERSHIP;
GRANT USAGE ON SCHEMA KITCHEN_SINK_STAGING.DATA  TO ROLE KS_APP_DEPLOYER;
GRANT USAGE ON SCHEMA KITCHEN_SINK_PROD.DATA TO ROLE KS_SALES_EAST;
GRANT USAGE ON SCHEMA KITCHEN_SINK_PROD.DATA TO ROLE KS_SALES_WEST;
GRANT USAGE ON SCHEMA KITCHEN_SINK_PROD.DATA TO ROLE KS_SALES_LEADERSHIP;
GRANT USAGE ON SCHEMA KITCHEN_SINK_PROD.DATA TO ROLE KS_APP_DEPLOYER;

-- ---------------------------------------------------------------------------
-- APPS schema — the CI deployer creates the Streamlit object; the broad viewer
-- role needs schema USAGE to open apps in either environment.
-- ---------------------------------------------------------------------------
GRANT USAGE ON SCHEMA KITCHEN_SINK_STAGING.APPS  TO ROLE KS_APP_DEPLOYER;
GRANT USAGE ON SCHEMA KITCHEN_SINK_STAGING.APPS  TO ROLE KS_STREAMLIT_VIEWER;
GRANT USAGE ON SCHEMA KITCHEN_SINK_PROD.APPS TO ROLE KS_APP_DEPLOYER;
GRANT USAGE ON SCHEMA KITCHEN_SINK_PROD.APPS TO ROLE KS_STREAMLIT_VIEWER;
GRANT CREATE STREAMLIT ON SCHEMA KITCHEN_SINK_STAGING.APPS  TO ROLE KS_APP_DEPLOYER;
GRANT CREATE STREAMLIT ON SCHEMA KITCHEN_SINK_PROD.APPS TO ROLE KS_APP_DEPLOYER;
