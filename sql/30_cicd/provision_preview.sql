/*
 * ============================================================================
 * 30_cicd/provision_preview.sql  —  Stand up an ephemeral PR preview database
 * ============================================================================
 *
 * Creates a TRANSIENT database for a PR preview and its APPS schema, owned by
 * the staging app-owner role so the preview app is owned by a role in the
 * policy owner-exemption. The DATA schema is added afterward by clone_data.sql
 * (cloned from prod). Runs as the scoped CI role.
 *
 * Parametrized:  snow sql -D pr_db=KITCHEN_SINK_PR_123 -f provision_preview.sql
 * ============================================================================
 */

USE ROLE KS_APP_DEPLOYER;

-- Transient (no Fail-safe) + dropped on PR close, so it's cheap and disposable.
CREATE OR REPLACE TRANSIENT DATABASE <% pr_db %>
  COMMENT = 'Kitchen Sink PR preview (ephemeral; dropped on PR close)';

CREATE SCHEMA IF NOT EXISTS <% pr_db %>.APPS;

-- Reachability: the app owner role operates in the db; viewers open the app;
-- business roles back the caller's-rights queries.
GRANT USAGE ON DATABASE <% pr_db %> TO ROLE KS_APP_STAGING;
GRANT USAGE ON DATABASE <% pr_db %> TO ROLE KS_STREAMLIT_VIEWER;
GRANT USAGE ON DATABASE <% pr_db %> TO ROLE KS_SALES_EAST;
GRANT USAGE ON DATABASE <% pr_db %> TO ROLE KS_SALES_WEST;
GRANT USAGE ON DATABASE <% pr_db %> TO ROLE KS_SALES_LEADERSHIP;
GRANT USAGE ON SCHEMA <% pr_db %>.APPS TO ROLE KS_STREAMLIT_VIEWER;

-- Hand APPS ownership to the staging app-owner role so it can create + own the
-- preview app (aligning with the owner-exemption). COPY CURRENT GRANTS keeps the
-- viewer USAGE grant above.
GRANT OWNERSHIP ON SCHEMA <% pr_db %>.APPS
  TO ROLE KS_APP_STAGING COPY CURRENT GRANTS;
