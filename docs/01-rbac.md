# Phase 1 — Role hierarchy, environments & governance

This phase builds the RBAC foundation that Phases 2 and 3 stand on. It is also the
direct answer to the question customers ask most: **"what's the best way to share
and govern these apps?"** The answer is *dedicated, functional roles* plus a clean
environment split — never app privileges pinned to a person's default role.

## The role model

```
                         SYSADMIN
                            │  (KS_APP_ADMIN granted up to SYSADMIN)
                            ▼
                      KS_APP_ADMIN            top governance role
        ┌───────────────┬────┴────┬───────────────┬──────────────┐
        ▼               ▼         ▼               ▼              ▼
 KS_APP_DEVELOPER  KS_APP_DEPLOYER  KS_APP_OWNER_PROD   KS_VIEWER_EAST / WEST / ALL
  (creates/owns      (CI/CD          (owns the           (end users; drive the
   the DEV app)       service role)   PROD app)           row access policy demo)
```

| Role | Purpose | Key privileges |
|------|---------|----------------|
| `KS_APP_ADMIN` | Governance; inherits all roles below so one operator can create, deploy, own, and test-view | (inherits everything) |
| `KS_APP_DEVELOPER` | Creates and owns the **dev** Streamlit app | OWNERSHIP on `KITCHEN_SINK_DEV.APPS`, `CREATE STREAMLIT`, `USAGE` on `KS_WH` + compute pool |
| `KS_APP_DEPLOYER` | CI/CD service role (Phase 3) | `CREATE STREAMLIT` + `USAGE` on **both** `APPS` schemas, warehouse, compute pool |
| `KS_APP_OWNER_PROD` | Owns the **prod** app object | OWNERSHIP on `KITCHEN_SINK_PROD.APPS`, warehouse, compute pool |
| `KS_VIEWER_EAST` | End-user viewer, EAST region | `USAGE` on dev db/schema + warehouse; app `USAGE` added in Phase 2 |
| `KS_VIEWER_WEST` | End-user viewer, WEST region | same, WEST region |
| `KS_VIEWER_ALL` | End-user viewer, account-wide | same, all regions |

### Why this shape

- **Separation of duties.** Roles are created by `USERADMIN`, granted by
  `SECURITYADMIN`, and objects are owned by `SYSADMIN` — Snowflake's recommended
  RBAC split. See `sql/00_foundation/01_roles.sql`.
- **Ownership follows the environment.** The `APPS` schema in each database is owned
  by the role responsible for that environment (`KS_APP_DEVELOPER` for dev,
  `KS_APP_OWNER_PROD` for prod). Objects created there inherit the right owner.
- **Sharing = granting a viewer role.** To share an app you grant `USAGE ON STREAMLIT`
  to a viewer role, then grant that role to users. Viewers never need direct access
  to the underlying tables when the app runs with **owner's rights** (Phase 2).
- **Governance = the viewer role is the control point.** Row access policies and
  restricted caller's rights (Phase 2) key off the viewer's role, so the same role
  hierarchy that *shares* the app also *governs* what each viewer sees.

## Environments

| Database | Schema | Owner role | Purpose |
|----------|--------|-----------|---------|
| `KITCHEN_SINK_DEV` | `APPS` | `KS_APP_DEVELOPER` | development |
| `KITCHEN_SINK_PROD` | `APPS` | `KS_APP_OWNER_PROD` | production |

Shared query warehouse: `KS_WH` (XSMALL, auto-suspend 60s).
Compute pool: `SYSTEM_COMPUTE_POOL_CPU` (account default; container runtime).

## Run it

```bash
snow sql -c <connection> -f sql/00_foundation/01_roles.sql
snow sql -c <connection> -f sql/00_foundation/02_databases.sql
snow sql -c <connection> -f sql/00_foundation/03_warehouse_and_pool.sql
```

All scripts are idempotent. The connection's user must be able to escalate to
`USERADMIN`, `SECURITYADMIN`, `SYSADMIN`, and `ACCOUNTADMIN` (the compute-pool
USAGE grant needs `ACCOUNTADMIN`).

## Verify

```sql
SHOW ROLES LIKE 'KS_%';
SHOW GRANTS TO ROLE KS_APP_ADMIN;      -- should list all 6 child roles
SHOW GRANTS TO ROLE KS_APP_DEPLOYER;   -- CREATE STREAMLIT on dev + prod APPS
SELECT SCHEMA_NAME, SCHEMA_OWNER
  FROM KITCHEN_SINK_DEV.INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = 'APPS';
```

## Next

Phase 2 makes this tangible: a single Streamlit app that queries the same table
through an **owner's-rights** connection and a **restricted caller's-rights**
connection side by side, so you can watch the viewer role change what's returned.
