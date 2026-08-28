# Pass the name of the connection from your ~/.snowflake/connections.toml as the
# argument to each recipe, e.g. `just setup my_connection`.
#
# Environment tiers:
#   prod     KITCHEN_SINK_PROD      source of truth (real data)
#   staging  KITCHEN_SINK_STAGING   scheduled clone of prod + CI deploy target
#   preview  KITCHEN_SINK_PR_<n>    ephemeral per-PR clone of prod (CI-managed)

# Bootstrap the foundation: roles, prod/staging databases (DATA + APPS schemas),
# warehouse, compute pool, and grants. Idempotent.

setup connection:
  snow sql -c {{connection}} -f sql/00_foundation/01_roles.sql
  snow sql -c {{connection}} -f sql/00_foundation/02_databases.sql
  snow sql -c {{connection}} -f sql/00_foundation/03_warehouse_and_pool.sql

# Sanity-check what setup created: the KS_* roles, the broad viewer grant to
# PUBLIC, and the governance role's inherited roles.

verify connection:
  snow sql -c {{connection}} -q "SHOW ROLES LIKE 'KS_%'; SHOW GRANTS OF ROLE KS_STREAMLIT_VIEWER; SHOW GRANTS TO ROLE KS_APP_ADMIN;"

# Build PROD.DATA as the source of truth (sales table, entitlement map, row
# access + masking policies, caller grants). Data DDL is env-parametrized.

data-prod connection:
  snow sql -c {{connection}} -D db=KITCHEN_SINK_PROD -D owner_role=KS_APP_OWNER_PROD -f sql/10_demo_data/01_sales_table.sql
  snow sql -c {{connection}} -D db=KITCHEN_SINK_PROD -D owner_role=KS_APP_OWNER_PROD -f sql/10_demo_data/02_user_region_map.sql
  snow sql -c {{connection}} -D db=KITCHEN_SINK_PROD -D owner_role=KS_APP_OWNER_PROD -f sql/10_demo_data/03_row_access_policy.sql
  snow sql -c {{connection}} -D db=KITCHEN_SINK_PROD -D owner_role=KS_APP_OWNER_PROD -f sql/10_demo_data/04_masking_policy.sql
  snow sql -c {{connection}} -D db=KITCHEN_SINK_PROD -D owner_role=KS_APP_OWNER_PROD -f sql/20_caller_grants/01_caller_grants.sql

# Refresh STAGING.DATA as a zero-copy clone of PROD.DATA (data comes down), then
# re-apply what a clone doesn't carry. Normally scheduled; run manually here.

refresh-staging connection:
  snow sql -c {{connection}} -D target_db=KITCHEN_SINK_STAGING -D source_db=KITCHEN_SINK_PROD -D owner_role=KS_APP_STAGING -f sql/25_env_refresh/clone_data.sql

# Deploy the environment-aware app to STAGING as the staging owner role, attach
# the PyPI mirror, and share it via the broad entry role. The same artifact is
# promoted to prod (and into PR previews) by CI/CD.

deploy connection:
  cd app && snow streamlit deploy rights_demo -c {{connection}} --role KS_APP_STAGING --replace
  snow sql -c {{connection}} -q "USE ROLE KS_APP_STAGING; ALTER STREAMLIT KITCHEN_SINK_STAGING.APPS.KITCHEN_SINK_RIGHTS_DEMO SET ARTIFACT_REPOSITORIES = ('snowflake.snowpark.pypi_shared_repository'); GRANT USAGE ON STREAMLIT KITCHEN_SINK_STAGING.APPS.KITCHEN_SINK_RIGHTS_DEMO TO ROLE KS_STREAMLIT_VIEWER;"

# WARNING: drops the KITCHEN_SINK databases, the KS_WH warehouse, and every KS_*
# role. There is no undo.

teardown connection:
  snow sql -c {{connection}} -f sql/99_teardown.sql
