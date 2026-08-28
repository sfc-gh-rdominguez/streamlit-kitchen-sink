# Streamlit in Snowflake — Kitchen Sink

A teaching repository for **applied field engineering**, focused on three patterns
customers ask about most when running Streamlit **in** Snowflake (SiS):

1. **Owner's rights vs. restricted caller's rights** — side-by-side in one app.
2. **CI/CD with GitHub Actions** — PRs, merge-to-main deploys, and dev → prod promotion.
3. **Role hierarchy** — how to *share* and *govern* these apps.

Every Snowflake object here is created by **idempotent, committed SQL** under `sql/` —
no click-ops. The git history is intentionally structured so it reads as a lesson.

## Learning path

| Phase | Topic | Where |
|------|-------|-------|
| 1 | Foundation: role hierarchy, environments, governance | `sql/00_foundation/`, `docs/01-rbac.md` |
| 2 | Owner's vs. restricted caller's rights (flagship demo) | `app/`, `sql/10_demo_data/`, `sql/20_caller_grants/`, `docs/02-rights-model.md` |
| 3 | CI/CD via GitHub Actions (dev → prod) | `.github/workflows/`, `sql/30_cicd/`, `docs/03-cicd.md` |

## Environments

Two databases in a single account model the promotion story:

- `KITCHEN_SINK_DEV.APPS` — development
- `KITCHEN_SINK_PROD.APPS` — production

Apps run on the **container runtime** (`SYSTEM$ST_CONTAINER_RUNTIME_PY3_11`) on the
`SYSTEM_COMPUTE_POOL_CPU` compute pool — required for restricted caller's rights.

## Running the setup SQL

Scripts are idempotent and grouped by phase. Run them in numeric order with a role
that can escalate to `USERADMIN`/`SECURITYADMIN`/`SYSADMIN` (and `ACCOUNTADMIN` where noted):

```bash
snow sql -c <connection> -f sql/00_foundation/01_roles.sql
snow sql -c <connection> -f sql/00_foundation/02_databases.sql
snow sql -c <connection> -f sql/00_foundation/03_warehouse_and_pool.sql
```

> Note: the scripts use explicit `USE ROLE` statements following Snowflake's
> recommended RBAC separation (USERADMIN creates roles, SECURITYADMIN grants,
> SYSADMIN owns objects).
