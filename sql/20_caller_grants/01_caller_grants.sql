/*
 * ============================================================================
 * Phase 2 · 20_caller_grants/01_caller_grants.sql  —  Caller grants + READ SESSION
 * ============================================================================
 *
 * Restricted caller's rights are an INTERSECTION of two things:
 *   1. the viewer actually holds the privilege (business roles hold SELECT on
 *      the sales table — see 10_demo_data/01_sales_table.sql), AND
 *   2. the app owner role holds a matching CALLER grant, defined here.
 *
 * We delegate the ability to manage caller grants to KS_APP_ADMIN (via
 * MANAGE CALLER GRANTS) to model real separation of duties, then grant the
 * caller privileges the app owner role (KS_APP_DEVELOPER) needs.
 *
 * READ SESSION is required for CURRENT_USER() + row access policies to work
 * inside a Streamlit in Snowflake app.
 *
 * Idempotent.
 * ============================================================================
 */

-- ---------------------------------------------------------------------------
-- Account-level grants (ACCOUNTADMIN)
-- ---------------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

-- Delegate caller-grant management to the governance role.
GRANT MANAGE CALLER GRANTS ON ACCOUNT TO ROLE KS_APP_ADMIN;

-- Required for context functions + row access policies in SiS.
GRANT READ SESSION ON ACCOUNT TO ROLE KS_APP_DEVELOPER;

-- ---------------------------------------------------------------------------
-- Caller grants to the app owner role (granted by the delegated role)
--
-- These say: "an app owned by KS_APP_DEVELOPER may run with the caller's USAGE
-- on the db/schema and SELECT on the sales table." The viewer still needs to
-- hold those privileges themselves for the app to use them.
-- ---------------------------------------------------------------------------
USE ROLE KS_APP_ADMIN;

GRANT CALLER USAGE ON DATABASE KITCHEN_SINK_DEV TO ROLE KS_APP_DEVELOPER;
GRANT CALLER USAGE ON SCHEMA KITCHEN_SINK_DEV.APPS TO ROLE KS_APP_DEVELOPER;
GRANT CALLER SELECT ON TABLE KITCHEN_SINK_DEV.APPS.SALES_BY_REGION TO ROLE KS_APP_DEVELOPER;
