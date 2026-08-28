/*
 * ============================================================================
 * 30_cicd/03_netpolicy_admin.sql  —  Scoped role for weekly network-policy refresh
 * ============================================================================
 *
 * The weekly refresh (scripts/refresh_gh_actions_network_policy.py) must update
 * the GitHub Actions network rules, but the CI deploy role must not hold
 * account-wide network-policy power. This dedicated role owns ONLY the
 * KS_DEPLOYER_GH_ACTIONS policy and its GH_ACTIONS_IPV4_* rules, plus CREATE
 * NETWORK RULE on their schema — enough to refresh, nothing more. It never
 * re-attaches the policy to the user (done once at initial setup), so it needs
 * no privilege over the KS_DEPLOYER user.
 *
 * Run once, after the policy has been created. Idempotent.
 * ============================================================================
 */

USE ROLE USERADMIN;
CREATE ROLE IF NOT EXISTS KS_NETPOLICY_ADMIN
  COMMENT = 'Kitchen Sink: owns + refreshes the KS_DEPLOYER GitHub Actions network policy';

USE ROLE SECURITYADMIN;
GRANT ROLE KS_NETPOLICY_ADMIN TO USER KS_DEPLOYER;

USE ROLE ACCOUNTADMIN;
GRANT USAGE ON DATABASE KITCHEN_SINK_PROD TO ROLE KS_NETPOLICY_ADMIN;
GRANT USAGE ON SCHEMA KITCHEN_SINK_PROD.PUBLIC TO ROLE KS_NETPOLICY_ADMIN;
GRANT CREATE NETWORK RULE ON SCHEMA KITCHEN_SINK_PROD.PUBLIC TO ROLE KS_NETPOLICY_ADMIN;

-- Hand ownership of the policy and its rules to the scoped role so it can ALTER
-- them on refresh. (Rule chunks created by future refreshes are owned by this
-- role automatically.)
GRANT OWNERSHIP ON NETWORK POLICY KS_DEPLOYER_GH_ACTIONS
  TO ROLE KS_NETPOLICY_ADMIN COPY CURRENT GRANTS;
GRANT OWNERSHIP ON NETWORK RULE KITCHEN_SINK_PROD.PUBLIC.GH_ACTIONS_IPV4_1 TO ROLE KS_NETPOLICY_ADMIN COPY CURRENT GRANTS;
GRANT OWNERSHIP ON NETWORK RULE KITCHEN_SINK_PROD.PUBLIC.GH_ACTIONS_IPV4_2 TO ROLE KS_NETPOLICY_ADMIN COPY CURRENT GRANTS;
GRANT OWNERSHIP ON NETWORK RULE KITCHEN_SINK_PROD.PUBLIC.GH_ACTIONS_IPV4_3 TO ROLE KS_NETPOLICY_ADMIN COPY CURRENT GRANTS;
GRANT OWNERSHIP ON NETWORK RULE KITCHEN_SINK_PROD.PUBLIC.GH_ACTIONS_IPV4_4 TO ROLE KS_NETPOLICY_ADMIN COPY CURRENT GRANTS;
GRANT OWNERSHIP ON NETWORK RULE KITCHEN_SINK_PROD.PUBLIC.GH_ACTIONS_IPV4_5 TO ROLE KS_NETPOLICY_ADMIN COPY CURRENT GRANTS;
GRANT OWNERSHIP ON NETWORK RULE KITCHEN_SINK_PROD.PUBLIC.GH_ACTIONS_IPV4_6 TO ROLE KS_NETPOLICY_ADMIN COPY CURRENT GRANTS;
