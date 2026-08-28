/*
 * ============================================================================
 * Phase 1 · 01_roles.sql  —  Role hierarchy for Streamlit apps
 * ============================================================================
 *
 * Two independent layers, plus the build/deploy roles:
 *
 *   1. APP ENTRY (broad, flat, reused across apps)
 *      KS_STREAMLIT_VIEWER  ->  granted to PUBLIC. Its only job is "you may
 *      open Streamlit apps." Every app grants USAGE ON STREAMLIT to this role,
 *      so you never create a per-app viewer role. What a user actually SEES is
 *      governed at the data layer, not here.
 *
 *   2. DATA / BUSINESS ROLES (foundational functional roles)
 *      KS_SALES_EAST / KS_SALES_WEST / KS_SALES_LEADERSHIP. These carry the
 *      SELECT grants on business data and represent job functions that already
 *      exist in a real org. Row-level visibility is enforced by a row access
 *      policy (see Phase 2), so these roles gate OBJECT access while the policy
 *      governs ROWS.
 *
 *   3. BUILD / DEPLOY / OWNERSHIP
 *      KS_APP_ADMIN (governance; inherits the roles below for testing),
 *      KS_APP_STAGING (dev app owner), KS_APP_DEPLOYER (CI/CD service role),
 *      KS_APP_OWNER_PROD (prod app owner).
 *
 * Key idea: entry is broad; data RBAC keeps users seeing only what they may.
 * That separation is only SAFE for an app running with restricted caller's
 * rights (Phase 2) -- an owner's-rights app shared to KS_STREAMLIT_VIEWER shows
 * every viewer the owner's full data.
 *
 * RBAC separation of duties: USERADMIN creates roles, SECURITYADMIN grants,
 * SYSADMIN owns objects (02/03). Idempotent: safe to re-run.
 * ============================================================================
 */

-- ---------------------------------------------------------------------------
-- Create roles (USERADMIN owns role creation)
-- ---------------------------------------------------------------------------
USE ROLE USERADMIN;

-- Build / deploy / ownership
CREATE ROLE IF NOT EXISTS KS_APP_ADMIN
  COMMENT = 'Kitchen Sink: governance role; inherits build/deploy + business roles';
CREATE ROLE IF NOT EXISTS KS_APP_STAGING
  COMMENT = 'Kitchen Sink: creates/owns the DEV Streamlit app';
CREATE ROLE IF NOT EXISTS KS_APP_DEPLOYER
  COMMENT = 'Kitchen Sink: CI/CD service role; deploys dev and prod';
CREATE ROLE IF NOT EXISTS KS_APP_OWNER_PROD
  COMMENT = 'Kitchen Sink: owns the PROD Streamlit app';

-- Broad app-entry role (reused across all apps)
CREATE ROLE IF NOT EXISTS KS_STREAMLIT_VIEWER
  COMMENT = 'Kitchen Sink: broad app-entry role; USAGE on apps only, no data grants';

-- Foundational business / data roles (job functions; carry data SELECT grants)
CREATE ROLE IF NOT EXISTS KS_SALES_EAST
  COMMENT = 'Kitchen Sink: business role — East region sales';
CREATE ROLE IF NOT EXISTS KS_SALES_WEST
  COMMENT = 'Kitchen Sink: business role — West region sales';
CREATE ROLE IF NOT EXISTS KS_SALES_LEADERSHIP
  COMMENT = 'Kitchen Sink: business role — sales leadership (all regions)';

-- ---------------------------------------------------------------------------
-- Build the hierarchy (SECURITYADMIN owns role grants)
-- ---------------------------------------------------------------------------
USE ROLE SECURITYADMIN;

-- Build/deploy roles roll up to the governance role.
GRANT ROLE KS_APP_STAGING  TO ROLE KS_APP_ADMIN;
GRANT ROLE KS_APP_DEPLOYER   TO ROLE KS_APP_ADMIN;
GRANT ROLE KS_APP_OWNER_PROD TO ROLE KS_APP_ADMIN;

-- Business roles also roll up to the governance role so an operator can
-- test-view the app as any region. (SYSADMIN inherits them transitively via
-- KS_APP_ADMIN below, keeping the standard admin hierarchy intact.)
GRANT ROLE KS_SALES_EAST       TO ROLE KS_APP_ADMIN;
GRANT ROLE KS_SALES_WEST       TO ROLE KS_APP_ADMIN;
GRANT ROLE KS_SALES_LEADERSHIP TO ROLE KS_APP_ADMIN;

GRANT ROLE KS_APP_ADMIN TO ROLE SYSADMIN;

-- The CI deployer assumes each environment's owner role to deploy/own apps as
-- that role (so app ownership stays aligned with the policy owner-exemption) and
-- to read prod when cloning. This is the CI identity's scoped power — it never
-- needs SYSADMIN or ACCOUNTADMIN.
GRANT ROLE KS_APP_STAGING    TO ROLE KS_APP_DEPLOYER;
GRANT ROLE KS_APP_OWNER_PROD TO ROLE KS_APP_DEPLOYER;

-- App entry is broad: everyone may open Streamlit apps.
GRANT ROLE KS_STREAMLIT_VIEWER TO ROLE PUBLIC;

-- ---------------------------------------------------------------------------
-- Grant the governance role to the current operator so you can assume/test
-- every role above. Replace CURRENT_USER() if setting up for someone else.
-- ---------------------------------------------------------------------------
SET operator = CURRENT_USER();
GRANT ROLE KS_APP_ADMIN TO USER IDENTIFIER($operator);
