# Pass the name of the connection from your ~/.snowflake/connections.toml as the
# argument to each recipe, e.g. `just setup my_connection`.

# Bootstrap the foundation: roles, dev/prod databases, warehouse, and grants.
# Scripts are idempotent, so this is safe to re-run.

setup connection:
  snow sql -c {{connection}} -f sql/00_foundation/01_roles.sql
  snow sql -c {{connection}} -f sql/00_foundation/02_databases.sql
  snow sql -c {{connection}} -f sql/00_foundation/03_warehouse_and_pool.sql

# Sanity-check what setup created: the KS_* roles, the broad viewer grant to
# PUBLIC, the governance role's inherited roles, and schema ownership.

verify connection:
  snow sql -c {{connection}} -q "SHOW ROLES LIKE 'KS_%'; SHOW GRANTS OF ROLE KS_STREAMLIT_VIEWER; SHOW GRANTS TO ROLE KS_APP_ADMIN;"

# Owner's-vs-caller's-rights demo: build the data layer (sales table, user->region
# map, row access policy) and the caller grants. Run after `setup`.

data connection:
  snow sql -c {{connection}} -f sql/10_demo_data/01_sales_table.sql
  snow sql -c {{connection}} -f sql/10_demo_data/02_user_region_map.sql
  snow sql -c {{connection}} -f sql/10_demo_data/03_row_access_policy.sql
  snow sql -c {{connection}} -f sql/20_caller_grants/01_caller_grants.sql

# Deploy the Streamlit app as the dev owner role so its owner's-rights view
# matches the row access policy, then share it via the broad entry role.

deploy connection:
  cd app && snow streamlit deploy rights_demo -c {{connection}} --role KS_APP_DEVELOPER --replace
  snow sql -c {{connection}} -q "USE ROLE KS_APP_DEVELOPER; ALTER STREAMLIT KITCHEN_SINK_DEV.APPS.KITCHEN_SINK_RIGHTS_DEMO SET ARTIFACT_REPOSITORIES = ('snowflake.snowpark.pypi_shared_repository'); GRANT USAGE ON STREAMLIT KITCHEN_SINK_DEV.APPS.KITCHEN_SINK_RIGHTS_DEMO TO ROLE KS_STREAMLIT_VIEWER;"

# WARNING: drops the KITCHEN_SINK databases, the KS_WH warehouse, and every KS_*
# role. There is no undo.

teardown connection:
  snow sql -c {{connection}} -f sql/99_teardown.sql
