# Streamlit in Snowflake — Kitchen Sink

A Streamlit-in-Snowflake app that throws in more than any one app reasonably
needs: owner's rights vs. restricted caller's rights side by side, a role
hierarchy for sharing and governance, and GitHub Actions CI/CD with per-PR
preview environments. It's the kitchen sink — if there was a Streamlit or
Snowflake feature worth showing off, it probably ended up in here somewhere.

The point is to be a reference you can read, run, and lift patterns from.
Everything is created by SQL under `sql/` and driven by the
[`justfile`](justfile). 

Have fun!

## Who this is for

The people who *govern* a Snowflake account — data platform leads, architects,
and admins — not the citizen developers themselves. It's about how to **enable
and govern** app authorship and sharing across an org, not how to write a
Streamlit app. Where citizen developers show up, it's as the people you're
enabling, described in the third person.

The [**`docs/`**](docs/README.md) directory is the heart of this repo — start
there. It's written to be read start to finish, building from the role hierarchy
up through the rights model and into CI/CD, so each pattern sets up the next.
The code here is really just the worked example behind that story; the docs are
where it's explained.

## Prerequisites

- [**Snowflake
CLI**](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index)
(`snow`) — used by every recipe.
- [**just**](https://github.com/casey/just) — the command runner.
- A **named connection** in `~/.snowflake/connections.toml`. Its role must be
able to create roles, databases, and warehouses during setup (the foundation SQL
uses explicit `USE ROLE`, so an admin-capable connection works).

## Getting started

Every recipe takes your connection name as its argument. Run them in order:

```sh
just setup           my_connection   # roles, databases, warehouse, compute pool, grants
just data-prod       my_connection   # build PROD.DATA: sales table, policies, caller grants
just refresh-staging my_connection   # clone PROD.DATA into STAGING.DATA
just deploy          my_connection   # deploy the app to staging and share it
```

Then check what was created, and tear it all down when you're done:

```sh
just verify   my_connection   # inspect the KS_* roles and grants
just teardown my_connection   # WARNING: drops all databases, the warehouse, and KS_* roles
```

Run `just` with no arguments to list every recipe.

