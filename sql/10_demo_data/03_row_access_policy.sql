/*
 * ============================================================================
 * Phase 2 · 10_demo_data/03_row_access_policy.sql  —  Row access policy
 * ============================================================================
 *
 * The policy produces the side-by-side contrast:
 *
 *   - Owner's-rights connection  -> the app runs as the owner role, so
 *     CURRENT_ROLE() is guaranteed to be the app owner (KS_APP_DEVELOPER in
 *     dev, KS_APP_OWNER_PROD in prod). Those roles get a FULL view.
 *
 *   - Restricted caller's-rights connection -> the app runs as the viewer, so
 *     CURRENT_ROLE() is the viewer's role (not an owner role) and CURRENT_USER()
 *     is the viewer. Rows are filtered by the USER_REGION_MAP entitlement.
 *
 * Note: CURRENT_ROLE() is used ONLY for the owner full-view exemption. Actual
 * per-viewer row filtering keys on CURRENT_USER(), per the decision to entitle
 * by user rather than by role.
 *
 * Idempotent (CREATE OR REPLACE + guarded ADD).
 * ============================================================================
 */

USE ROLE KS_APP_DEVELOPER;

-- Detach any existing policy first so CREATE OR REPLACE has no references,
-- then (re)create and attach. Safe on an unprotected table.
ALTER TABLE KITCHEN_SINK_DEV.APPS.SALES_BY_REGION DROP ALL ROW ACCESS POLICIES;

CREATE OR REPLACE ROW ACCESS POLICY KITCHEN_SINK_DEV.APPS.SALES_REGION_POLICY
  AS (region VARCHAR) RETURNS BOOLEAN ->
    -- Owner's-rights path: the app owner role sees all rows.
    CURRENT_ROLE() IN ('KS_APP_DEVELOPER', 'KS_APP_OWNER_PROD')
    -- Caller's-rights path: filter by the viewer's entitlement.
    OR EXISTS (
      SELECT 1
      FROM KITCHEN_SINK_DEV.APPS.USER_REGION_MAP m
      WHERE m.username = CURRENT_USER()
        AND (m.region = region OR m.region = 'ALL')
    );

ALTER TABLE KITCHEN_SINK_DEV.APPS.SALES_BY_REGION
  ADD ROW ACCESS POLICY KITCHEN_SINK_DEV.APPS.SALES_REGION_POLICY ON (region);
