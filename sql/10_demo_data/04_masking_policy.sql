/*
 * ============================================================================
 * Phase 2 · 10_demo_data/04_masking_policy.sql  —  Column-level masking
 * ============================================================================
 *
 * Layers column-level governance on top of the row access policy:
 *
 *   - Owner's-rights connection  -> CURRENT_ROLE() is the app owner role, which
 *     is unmasked and sees the real rep name.
 *   - Restricted caller's-rights -> CURRENT_ROLE() is the viewer's role, which
 *     is masked and sees '*** masked ***'.
 *
 * We key the unmask on CURRENT_ROLE() (the primary role), NOT IS_ROLE_IN_SESSION.
 * Under caller's rights the app activates the viewer's roles as SECONDARY roles;
 * CURRENT_ROLE() still returns the primary role, so the owner's app role only
 * matches on the owner's-rights connection. That keeps the two sides distinct.
 *
 * Idempotent: CREATE ... IF NOT EXISTS + SET ... FORCE (FORCE atomically
 * (re)attaches even if a masking policy is already on the column).
 * ============================================================================
 */

USE ROLE KS_APP_DEVELOPER;

CREATE MASKING POLICY IF NOT EXISTS KITCHEN_SINK_DEV.APPS.MASK_REP
  AS (val VARCHAR) RETURNS VARCHAR ->
    CASE
      WHEN CURRENT_ROLE() IN ('KS_APP_DEVELOPER', 'KS_APP_OWNER_PROD') THEN val
      ELSE '*** masked ***'
    END;

ALTER TABLE KITCHEN_SINK_DEV.APPS.SALES_BY_REGION
  MODIFY COLUMN rep SET MASKING POLICY KITCHEN_SINK_DEV.APPS.MASK_REP FORCE;
