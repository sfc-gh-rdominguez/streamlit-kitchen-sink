/*
 * ============================================================================
 * Phase 4 · 40_citizen_dev/00_sandbox.sql  —  Per-team citizen-dev sandbox
 * ============================================================================
 *
 * The "other end of the spectrum" from the curated app: a self-service sandbox
 * where a business role builds its OWN owner's-rights Streamlit, bounded to its
 * own data by nothing more than the grants it already holds. These apps are
 * ephemeral and not business-critical, so they skip the whole curated lifecycle
 * (no staging, no CI/CD, no gated promotion).
 *
 * Run once per team:
 *   snow sql -D team=EAST -D role=KS_SALES_EAST -f sql/40_citizen_dev/00_sandbox.sql
 *   snow sql -D team=WEST -D role=KS_SALES_WEST -f sql/40_citizen_dev/00_sandbox.sql
 *
 * Two ideas make this safe without a god-role:
 *
 *   1. CREATE STREAMLIT is a schema-level privilege that says NOTHING about
 *      data. It's granted on the team's own sandbox schema, so the citizen dev
 *      can build — but what the app can read is fixed entirely by the role's
 *      SELECT grants (01_sandbox_data.sql). The app can only ever touch its own
 *      team's data.
 *
 *   2. The sandbox schema is created WITH MANAGED ACCESS. The citizen dev OWNS
 *      the app they create, but in a managed-access schema an object owner
 *      cannot GRANT privileges on their own objects — only the schema owner can.
 *      So the builder can't self-share the app; sharing is the schema owner's
 *      call. Build on your data, share to your team.
 *
 * Idempotent.
 * ============================================================================
 */

-- ---------------------------------------------------------------------------
-- SYSADMIN owns the sandbox container. It stays the schema owner, so it is the
-- role that decides who each app is shared with (managed access, see below).
-- ---------------------------------------------------------------------------
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SANDBOX
  COMMENT = 'Kitchen Sink — citizen-developer sandboxes (ephemeral, not business-critical)';

-- MANAGED ACCESS: object owners cannot self-grant; the schema owner (SYSADMIN
-- here) controls who an app is shared with.
CREATE SCHEMA IF NOT EXISTS SANDBOX.<% team %> WITH MANAGED ACCESS
  COMMENT = 'Citizen-dev sandbox for <% role %>';

-- ---------------------------------------------------------------------------
-- Grants to the team's business role (SECURITYADMIN holds MANAGE GRANTS).
-- CREATE STREAMLIT lets them build; it hands out NO data access on its own.
-- USAGE on KS_WH is normally already present from the foundation phase; granted
-- again here so the sandbox is self-documenting about what it needs.
-- ---------------------------------------------------------------------------
USE ROLE SECURITYADMIN;

GRANT USAGE ON DATABASE SANDBOX                            TO ROLE <% role %>;
GRANT USAGE, CREATE STREAMLIT ON SCHEMA SANDBOX.<% team %> TO ROLE <% role %>;
GRANT USAGE ON WAREHOUSE KS_WH                             TO ROLE <% role %>;
