# Owner's rights vs. Restricted Caller's rights

In the previous chapter we learned a lesson: don't create roles for _every_
application. Instead, share it with "everyone" via a dedicated viewer role that
rolls up to `PUBLIC` and let your existing RBAC within your account determine
access to data. Here, we'll see how the latter actually works.

In our sample Streamlit application, we run the same query side-by-side; one
invokes Owner's Rights while the other invokes Caller's Rights:

| Column | Connection | Runs as | Sees |
|--------|-----------|---------|------|
| Owner's rights | `st.connection("snowflake")` | the app **owner** role | every row, unmasked |
| Restricted caller's rights | `st.connection("snowflake-callers-rights")` | the **viewer** | only their entitled rows, masked |

The app code is identical on both sides — same string of SQL, same table.
Nothing in the Python knows or cares who's looking. The entire difference is
produced by governance policies sitting on
`KITCHEN_SINK_STAGING.DATA.SALES_BY_REGION`, which is exactly where you want
that decision to live: in the data, not in the app.

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

- **Owner's Rights** executes with the app owner's role. Don't forget, in
Snowflake, apps (along with all objects) are owned by **roles**, not users. In
Streamlit in Snowflake, `CURRENT_ROLE()` under owner's rights is *always* the
owner — no matter who opened the app — so the policy's owner branch hands back
the full view. An app like this couldn't care less who the user is...the only
identity it's aware of is that of the role which created it. Why would anyone
want this? See the addendum at the end of this chapter.
- **Restricted Caller's Rights** executes as the **signed-in viewer**, so
`CURRENT_USER()` is that actual person. In our example, the RAP joins them to
the entitlement table (`USER_REGION_MAP`) and returns only their region (`ALL`
sees everything).

Here's the row access policy that does it — both branches live in one body:

```sql
CREATE OR REPLACE ROW ACCESS POLICY SALES_REGION_POLICY
  AS (region VARCHAR) RETURNS BOOLEAN ->
    -- Owner's-rights path: the app owner role sees all rows.
    CURRENT_ROLE() IN ('KS_APP_STAGING', 'KS_APP_OWNER_PROD')
    -- Caller's-rights path: filter by the viewer's entitlement.
    OR EXISTS (
      SELECT 1 FROM USER_REGION_MAP m
      WHERE m.username = CURRENT_USER()
        AND (m.region = region OR m.region = 'ALL')
    );

ALTER TABLE SALES_BY_REGION ADD ROW ACCESS POLICY SALES_REGION_POLICY ON (region);
```

Two things to notice. The owner branch is a plain `CURRENT_ROLE()` check, so
it's the app owner — never a viewer — that trips it. And `USER_REGION_MAP` is
referenced *unqualified*: the policy is created inside `<db>.DATA`, so the name
resolves within whatever schema it lives in. That's deliberate — a zero-copy
clone of the schema rewires the reference to the *clone's* own entitlement
table, so a dev copy reads dev entitlements instead of accidentally leaking
prod's.

## How each connection figures out who you are

Neither the role nor the user is hardcoded anywhere in the app. Each connection
arrives at an identity by a different route:

- **Owner's Rights** runs as the **owner of the `STREAMLIT` object**
(`KS_APP_STAGING`), which is fixed the moment the app is deployed.
`CURRENT_ROLE()` is that owner role for everyone, forever, regardless of who
they are.
- **Restricted Caller's Rights** runs as the **viewer**. Snowflake mints a
short-lived viewer token at session start, so `CURRENT_USER()` is whoever opened
the app and `CURRENT_ROLE()` is *their* default role. The app then runs `USE
SECONDARY ROLES ALL` to light up the rest of the viewer's granted roles.

Because the policies key on functional role *names* (`KS_*`) and
`CURRENT_USER()` — never on a specific human — the same objects behave
identically no matter who set them up or who's currently poking at the app.
Nobody's name is baked into a policy body.

## Two layers of governance, stacked

The demo runs **row-level** and **column-level** controls at the same time, so
the two connections differ both in *which rows* and *which values* they get:

- **Row access policy** on `region` — the owner role sees all rows; a caller
sees only their entitled region.
- **Masking policy** on `rep` — the owner role sees the real name; anyone else
sees `*** masked ***`. The unmask keys on `CURRENT_ROLE()` (the *primary* role),
so activating the viewer's roles as *secondary* roles doesn't unmask anything.
That's a deliberate subtlety: a caller who happens to inherit the owner role
somewhere up the tree is *still* masked, because it isn't their primary role.

```sql
CREATE MASKING POLICY MASK_REP
  AS (val VARCHAR) RETURNS VARCHAR ->
    CASE
      WHEN CURRENT_ROLE() IN ('KS_APP_STAGING', 'KS_APP_OWNER_PROD') THEN val
      ELSE '*** masked ***'
    END;

ALTER TABLE SALES_BY_REGION MODIFY COLUMN rep SET MASKING POLICY MASK_REP;
```

## Why caller's rights takes two things, not one

Restricted caller's rights is an **intersection** — the viewer's own privileges
*and* the owner's caller grants both have to line up:

1. the viewer must actually hold `SELECT` on the table (the `KS_SALES_*`
   business roles carry it), **and**
2. the app owner role must hold a matching **caller grant** (`GRANT CALLER
   SELECT ON TABLE … TO ROLE KS_APP_STAGING`).

Either one alone gets you nothing. The caller grant doesn't *hand out* access;
it only *permits the app* to exercise a privilege the viewer already has. Miss
either half and the query comes back empty — which, the first time it happens to
you, is a genuinely confusing five minutes.

The owner-side half is a `GRANT CALLER`, delegated to the governance role that
manages them:

```sql
-- KS_APP_ADMIN holds MANAGE CALLER GRANTS, so it can hand these out.
GRANT CALLER USAGE  ON DATABASE KITCHEN_SINK_STAGING            TO ROLE KS_APP_STAGING;
GRANT CALLER USAGE  ON SCHEMA   KITCHEN_SINK_STAGING.DATA       TO ROLE KS_APP_STAGING;
GRANT CALLER SELECT ON TABLE    KITCHEN_SINK_STAGING.DATA.SALES_BY_REGION
                                                               TO ROLE KS_APP_STAGING;
```

## What a viewer is actually entitled to

Row visibility comes from the entitlement table `USER_REGION_MAP`, keyed on
`CURRENT_USER()`. A viewer with no row in it has no entitlement, so their
caller's-rights view is simply empty — no error, no data, just a polite void.
You grant someone access by adding them to the table with a region (or `ALL`).
That's the whole governance argument of this repo in one sentence: **app access
is broad, but data entitlement is precise and lives in the data layer.**

```sql
CREATE TABLE USER_REGION_MAP (
  username  VARCHAR,   -- matches CURRENT_USER()
  region    VARCHAR    -- 'EAST' | 'WEST' | 'ALL'
);

INSERT INTO USER_REGION_MAP VALUES
  ('ALICE', 'WEST'),   -- Alice sees West
  ('BOSS',  'ALL');    -- leadership sees everything
```

## What the model requires

These are the conditions that make the two-column contrast possible. The setup
SQL in this repo applies all of them so you don't have to remember them — but
here they are, so that when you adapt this to your own tables you know which
knobs matter:

- **Container runtime** (`SYSTEM$ST_CONTAINER_RUNTIME_PY3_11`) — restricted
caller's rights simply isn't available in the warehouse runtime.
- **`READ SESSION` on the owner role** — so `CURRENT_USER()` and row access
policies resolve correctly inside a Streamlit in Snowflake app.
- **Caller grants**, delegated via `MANAGE CALLER GRANTS` to `KS_APP_ADMIN` —
the owner-side half of the intersection above.
- **A declared `pyproject.toml`** resolved from the built-in Snowflake PyPI
mirror (`snowflake.snowpark.pypi_shared_repository`). A container app overrides
the runtime's default packages, so it has to declare its own — including
`streamlit>=1.53.1`, the floor for caller's rights — and the mirror installs
them with no external access integration and no trip to the internet.

## Next Up

The objects behind this pattern are created by the SQL under `sql/10_demo_data/`
and `sql/20_caller_grants/` — built in prod by `just data-prod`, cloned down to
staging by `just refresh-staging`, and shared by `just deploy`. So far you've
been running those recipes by hand against one connection. The [next
chapter](03-cicd.md) hands the whole routine to GitHub Actions: code promoted up
through environments, data cloned down, and a throwaway preview environment spun
up for every pull request.
