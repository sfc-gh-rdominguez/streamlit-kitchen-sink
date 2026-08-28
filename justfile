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

# WARNING: drops the KITCHEN_SINK databases, the KS_WH warehouse, and every KS_*
# role. There is no undo.

teardown connection:
  snow sql -c {{connection}} -f sql/99_teardown.sql
