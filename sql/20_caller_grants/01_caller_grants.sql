/*
 * ============================================================================
 * Phase 2 · 20_caller_grants/01_caller_grants.sql  —  Caller grants (parametrized)
 * ============================================================================
 *
 * Run per environment:
 *   snow sql -D db=KITCHEN_SINK_PROD -D owner_role=KS_APP_OWNER_PROD -f ...
 *
 * Restricted caller's rights is an INTERSECTION: the viewer must hold SELECT on
 * the table (business roles do), AND the app owner role must hold matching
 * caller grants (below). Caller grants are re-applied to dev after a clone,
 * since grants of this kind are not guaranteed to survive cloning.
 *
 * Idempotent.
 * ============================================================================
 */

-- ---------------------------------------------------------------------------
-- Account-level grants (ACCOUNTADMIN)
-- ---------------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

-- Delegate caller-grant management to the governance role (account-wide; only
-- needs to run once, harmless to repeat).
GRANT MANAGE CALLER GRANTS ON ACCOUNT TO ROLE KS_APP_ADMIN;

-- Required for CURRENT_USER() + row access policies inside SiS, for this env's
-- app owner role.
GRANT READ SESSION ON ACCOUNT TO ROLE <% owner_role %>;

-- ---------------------------------------------------------------------------
-- Caller grants to the env's app owner role (granted by the delegated role)
-- ---------------------------------------------------------------------------
USE ROLE KS_APP_ADMIN;

GRANT CALLER USAGE ON DATABASE <% db %> TO ROLE <% owner_role %>;
GRANT CALLER USAGE ON SCHEMA <% db %>.DATA TO ROLE <% owner_role %>;
GRANT CALLER SELECT ON TABLE <% db %>.DATA.SALES_BY_REGION TO ROLE <% owner_role %>;
GRANT CALLER USAGE ON WAREHOUSE KS_WH TO ROLE <% owner_role %>;
