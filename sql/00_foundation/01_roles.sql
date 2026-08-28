/*
 * ============================================================================
 * Phase 1 · 01_roles.sql  —  Dedicated role hierarchy for Streamlit apps
 * ============================================================================
 *
 * Teaching point: use FUNCTIONAL, dedicated roles — never tie app privileges
 * to a person's default role. This is the foundation the caller's-vs-owner's
 * rights demo (Phase 2) and the CI/CD promotion (Phase 3) both build on.
 *
 * RBAC separation of duties (Snowflake best practice):
 *   - USERADMIN     creates roles
 *   - SECURITYADMIN grants roles to roles (builds the hierarchy)
 *   - SYSADMIN      owns databases/warehouses (see 02/03)
 *
 * Idempotent: safe to re-run. Role-to-role GRANTs are no-ops if already present.
 *
 * Role map
 * --------
 *   KS_APP_ADMIN        Top governance role. Inherits every role below, so an
 *                       operator using it can create, deploy, own, and test-view
 *                       apps. Granted up to SYSADMIN.
 *   KS_APP_DEVELOPER    Creator / owner of the DEV app. CREATE STREAMLIT in dev.
 *   KS_APP_DEPLOYER     CI/CD service role. Deploys to dev and prod (Phase 3).
 *   KS_APP_OWNER_PROD   Owns the PROD app object.
 *   KS_VIEWER_EAST      End-user viewer, scoped to the EAST region (Phase 2 RAP).
 *   KS_VIEWER_WEST      End-user viewer, scoped to the WEST region (Phase 2 RAP).
 *   KS_VIEWER_ALL       End-user viewer with account-wide visibility.
 * ============================================================================
 */

-- ---------------------------------------------------------------------------
-- Create roles (USERADMIN owns role creation)
-- ---------------------------------------------------------------------------
USE ROLE USERADMIN;

CREATE ROLE IF NOT EXISTS KS_APP_ADMIN
  COMMENT = 'Kitchen Sink: top governance role; inherits all app roles';
CREATE ROLE IF NOT EXISTS KS_APP_DEVELOPER
  COMMENT = 'Kitchen Sink: creates/owns the DEV Streamlit app';
CREATE ROLE IF NOT EXISTS KS_APP_DEPLOYER
  COMMENT = 'Kitchen Sink: CI/CD service role; deploys dev and prod';
CREATE ROLE IF NOT EXISTS KS_APP_OWNER_PROD
  COMMENT = 'Kitchen Sink: owns the PROD Streamlit app';
CREATE ROLE IF NOT EXISTS KS_VIEWER_EAST
  COMMENT = 'Kitchen Sink: end-user viewer scoped to EAST region';
CREATE ROLE IF NOT EXISTS KS_VIEWER_WEST
  COMMENT = 'Kitchen Sink: end-user viewer scoped to WEST region';
CREATE ROLE IF NOT EXISTS KS_VIEWER_ALL
  COMMENT = 'Kitchen Sink: end-user viewer with account-wide visibility';

-- ---------------------------------------------------------------------------
-- Build the hierarchy (SECURITYADMIN owns role grants)
--
-- Granting a child role TO a parent lets the parent inherit the child's
-- privileges. We roll everything up to KS_APP_ADMIN, then KS_APP_ADMIN up to
-- SYSADMIN so the standard admin hierarchy stays intact.
-- ---------------------------------------------------------------------------
USE ROLE SECURITYADMIN;

GRANT ROLE KS_APP_DEVELOPER  TO ROLE KS_APP_ADMIN;
GRANT ROLE KS_APP_DEPLOYER   TO ROLE KS_APP_ADMIN;
GRANT ROLE KS_APP_OWNER_PROD TO ROLE KS_APP_ADMIN;
GRANT ROLE KS_VIEWER_EAST    TO ROLE KS_APP_ADMIN;
GRANT ROLE KS_VIEWER_WEST    TO ROLE KS_APP_ADMIN;
GRANT ROLE KS_VIEWER_ALL     TO ROLE KS_APP_ADMIN;

GRANT ROLE KS_APP_ADMIN TO ROLE SYSADMIN;

-- ---------------------------------------------------------------------------
-- Grant the roles to the current operator so you can assume/test them.
-- Replace CURRENT_USER() usage below if setting up for another operator.
-- ---------------------------------------------------------------------------
SET operator = CURRENT_USER();
GRANT ROLE KS_APP_ADMIN TO USER IDENTIFIER($operator);
