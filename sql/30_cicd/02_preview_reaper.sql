/*
 * ============================================================================
 * 30_cicd/02_preview_reaper.sql  —  Safety-net cleanup of orphaned PR previews
 * ============================================================================
 *
 * OPTIONAL, admin-installed. The pr-teardown workflow drops a PR's database on
 * close/merge; this scheduled task is a backstop that drops any PR preview
 * database older than 3 days in case a teardown event was ever missed.
 *
 * Installed by an admin (not the scoped CI role). Resume with:
 *   ALTER TASK KITCHEN_SINK_PROD.APPS.PREVIEW_REAPER RESUME;
 * ============================================================================
 */

USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE TASK KITCHEN_SINK_PROD.APPS.PREVIEW_REAPER
  WAREHOUSE = KS_WH
  SCHEDULE = 'USING CRON 0 3 * * * America/Los_Angeles'
  COMMENT = 'Drops KITCHEN_SINK_PR_* preview databases older than 3 days'
AS
DECLARE
  stale CURSOR FOR
    SELECT database_name
    FROM SNOWFLAKE.ACCOUNT_USAGE.DATABASES
    WHERE database_name LIKE 'KITCHEN\\_SINK\\_PR\\_%' ESCAPE '\\'
      AND deleted IS NULL
      AND created < DATEADD('day', -3, CURRENT_TIMESTAMP());
BEGIN
  FOR rec IN stale DO
    EXECUTE IMMEDIATE 'DROP DATABASE IF EXISTS ' || rec.database_name;
  END FOR;
END;

-- Tasks are created suspended; resume to activate.
-- ALTER TASK KITCHEN_SINK_PROD.APPS.PREVIEW_REAPER RESUME;
