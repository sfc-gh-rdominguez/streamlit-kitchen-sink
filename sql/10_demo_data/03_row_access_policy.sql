/*
 * ============================================================================
 * Phase 2 · 10_demo_data/03_row_access_policy.sql  —  Row access (parametrized)
 * ============================================================================
 *
 * Owner roles get a full view (owner's-rights connection); everyone else is
 * filtered by USER_REGION_MAP on CURRENT_USER() (caller's-rights connection).
 *
 * IMPORTANT: the mapping table is referenced UNQUALIFIED. The policy is created
 * in <db>.DATA (USE SCHEMA below), so the reference resolves within that schema
 * — and a zero-copy clone of the schema rewires it to the clone's own map
 * (verified). Do not qualify it with a database name, or a cloned dev copy would
 * read prod's entitlements.
 *
 * Idempotent (detach, replace, reattach).
 * ============================================================================
 */

USE ROLE <% owner_role %>;
USE SCHEMA <% db %>.DATA;

ALTER TABLE SALES_BY_REGION DROP ALL ROW ACCESS POLICIES;

CREATE OR REPLACE ROW ACCESS POLICY SALES_REGION_POLICY
  AS (region VARCHAR) RETURNS BOOLEAN ->
    -- Owner's-rights path: the app owner role sees all rows.
    CURRENT_ROLE() IN ('KS_APP_DEVELOPER', 'KS_APP_OWNER_PROD')
    -- Caller's-rights path: filter by the viewer's entitlement (unqualified ->
    -- resolves within this schema; clone-safe).
    OR EXISTS (
      SELECT 1 FROM USER_REGION_MAP m
      WHERE m.username = CURRENT_USER()
        AND (m.region = region OR m.region = 'ALL')
    );

ALTER TABLE SALES_BY_REGION ADD ROW ACCESS POLICY SALES_REGION_POLICY ON (region);
