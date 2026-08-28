/*
 * ============================================================================
 * 99_teardown.sql  —  Remove everything the foundation scripts created
 * ============================================================================
 *
 * WARNING: drops the KITCHEN_SINK databases (and all app objects inside them),
 * the KS_WH warehouse, and every KS_* role. There is no undo.
 *
 * Idempotent: DROP ... IF EXISTS.
 * ============================================================================
 */

USE ROLE SYSADMIN;
DROP DATABASE IF EXISTS KITCHEN_SINK_STAGING;
DROP DATABASE IF EXISTS KITCHEN_SINK_PROD;
DROP WAREHOUSE IF EXISTS KS_WH;

-- Dropping the roles also removes their grants (compute-pool USAGE, the
-- KS_STREAMLIT_VIEWER -> PUBLIC grant, etc.).
USE ROLE USERADMIN;
DROP ROLE IF EXISTS KS_STREAMLIT_VIEWER;
DROP ROLE IF EXISTS KS_SALES_EAST;
DROP ROLE IF EXISTS KS_SALES_WEST;
DROP ROLE IF EXISTS KS_SALES_LEADERSHIP;
DROP ROLE IF EXISTS KS_APP_STAGING;
DROP ROLE IF EXISTS KS_APP_DEPLOYER;
DROP ROLE IF EXISTS KS_APP_OWNER_PROD;
DROP ROLE IF EXISTS KS_APP_ADMIN;
