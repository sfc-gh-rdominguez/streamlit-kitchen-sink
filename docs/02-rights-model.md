# Owner's rights vs. restricted caller's rights

One Streamlit app runs the **same query** through two connections, side by side:

| Column | Connection | Runs as | Sees |
|--------|-----------|---------|------|
| Owner's rights | `st.connection("snowflake")` | the app **owner** role | every row, unmasked |
| Restricted caller's rights | `st.connection("snowflake-callers-rights")` | the **viewer** | only their entitled rows, masked |

The app code is identical on both sides. The difference is produced entirely by
governance policies on `KITCHEN_SINK_STAGING.DATA.SALES_BY_REGION`.

## How it works

```mermaid
graph LR
    subgraph app["KITCHEN_SINK_RIGHTS_DEMO (container runtime)"]
        O["owner's-rights conn"]
        C["caller's-rights conn"]
    end
    O -->|"CURRENT_ROLE() = KS_APP_STAGING"| P{Row access policy}
    C -->|"CURRENT_USER() = viewer"| P
    P -->|owner role| ALL["all rows"]
    P -->|"USER_REGION_MAP lookup"| FILT["viewer's region only"]
```

- **Owner's rights** executes with the app owner's role. In Streamlit in
  Snowflake, `CURRENT_ROLE()` under owner's rights is *always* the owner role, so
  the policy's owner branch returns a full view.
- **Restricted caller's rights** executes as the signed-in viewer, so
  `CURRENT_USER()` is the viewer. The policy joins that to `USER_REGION_MAP` and
  returns only the entitled region (`ALL` sees everything).

## How each connection resolves identity

Neither the role nor the user is hardcoded in the app — each connection derives
identity a different way:

- **Owner's rights** runs as the **owner of the `STREAMLIT` object**
  (`KS_APP_STAGING`), fixed when the app is deployed. `CURRENT_ROLE()` is that
  owner role for everyone who opens the app, regardless of who they are.
- **Restricted caller's rights** runs as the **viewer**. Snowflake mints a
  short-lived viewer token at session start, so `CURRENT_USER()` is whoever
  opened the app and `CURRENT_ROLE()` is *their* default role. The app then runs
  `USE SECONDARY ROLES ALL` to activate the viewer's other granted roles.

Because the policies key on functional role *names* (`KS_*`) and `CURRENT_USER()`
— never on a specific person — the same objects behave identically no matter who
sets them up or opens the app.

## Two layers of governance

The demo stacks **row-level** and **column-level** controls, so the two
connections differ in *which rows* and *which values* they see:

- **Row access policy** on `region` — the owner role sees all rows; a caller sees
  only their entitled region.
- **Masking policy** on `rep` — the owner role sees the real name; any other role
  (i.e. a caller) sees `*** masked ***`. The unmask keys on `CURRENT_ROLE()` (the
  *primary* role), so activating the viewer's roles as *secondary* roles does not
  unmask them — which is why a caller who happens to hold the owner role by
  inheritance is still masked.

## Why caller's rights needs two things

Restricted caller's rights is an **intersection** of the viewer's privileges and
the owner's caller grants:

1. the viewer must actually hold `SELECT` on the table (the business roles
   `KS_SALES_*` carry it), **and**
2. the app owner role must hold a matching **caller grant**
   (`GRANT CALLER SELECT ON TABLE … TO ROLE KS_APP_STAGING`).

Either alone is not enough — the caller grant only *permits* the app to use a
privilege the viewer already has.

## What a viewer is entitled to

Row visibility comes from `USER_REGION_MAP`, keyed on `CURRENT_USER()`. A viewer
with no row in that table has no entitlement, so their caller's-rights view is
empty. Entitlement is granted by adding the user to the map with a region (or
`ALL`). That is the governance point of the whole pattern: **app access is broad,
but data entitlement is precise and lives in the data layer.**

## What the model requires

These are the conditions that make the two-connection contrast possible; the
setup SQL in this repo applies them:

- **Container runtime** (`SYSTEM$ST_CONTAINER_RUNTIME_PY3_11`) — restricted
  caller's rights is not available in the warehouse runtime.
- **`READ SESSION` on the owner role** — so `CURRENT_USER()` and row access
  policies resolve inside a Streamlit in Snowflake app.
- **Caller grants**, delegated through `MANAGE CALLER GRANTS` to `KS_APP_ADMIN` —
  the owner-side half of the intersection above.
- **A declared `pyproject.toml`** resolved from the built-in Snowflake PyPI
  mirror (`snowflake.snowpark.pypi_shared_repository`). A container app overrides
  the runtime's default packages, so it must declare its own — including
  `streamlit>=1.53.1`, the minimum for caller's rights — and the mirror installs
  them with no external access integration or internet.

---

The objects behind this pattern are created by the SQL under `sql/10_demo_data/`
and `sql/20_caller_grants/`, and applied together by the `just data` and
`just deploy` recipes.
