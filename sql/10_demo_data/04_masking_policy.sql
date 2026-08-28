/*
 * ============================================================================
 * Phase 2 · 10_demo_data/04_masking_policy.sql  —  Column masking (parametrized)
 * ============================================================================
 *
 * Owner roles see the real rep name (owner's-rights); every other role sees
 * '*** masked ***' (caller's-rights). Unmask keys on CURRENT_ROLE() (primary
 * role), so activating roles as SECONDARY roles does not unmask.
 *
 * Created unqualified in <db>.DATA so a schema clone carries its own copy.
 * Idempotent: CREATE ... IF NOT EXISTS + SET ... FORCE.
 * ============================================================================
 */

USE ROLE <% owner_role %>;
USE SCHEMA <% db %>.DATA;

CREATE MASKING POLICY IF NOT EXISTS MASK_REP
  AS (val VARCHAR) RETURNS VARCHAR ->
    CASE
      WHEN CURRENT_ROLE() IN ('KS_APP_DEVELOPER', 'KS_APP_OWNER_PROD') THEN val
      ELSE '*** masked ***'
    END;

ALTER TABLE SALES_BY_REGION MODIFY COLUMN rep SET MASKING POLICY MASK_REP FORCE;
