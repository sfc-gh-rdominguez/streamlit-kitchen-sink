"""
Owner's rights vs. restricted caller's rights — side by side.

The same query runs through two connections in one app:

  * Owner's rights            -> st.connection("snowflake")
  * Restricted caller's rights -> st.connection("snowflake-callers-rights")

A row access policy + masking policy on the SALES_BY_REGION table produce the
contrast: the owner role sees every row unmasked; a caller sees only their
entitled region with the rep name masked.

The app is environment-agnostic: it queries the DATA schema of its OWN database
(KITCHEN_SINK_STAGING, KITCHEN_SINK_PROD, or a PR preview db), so the same code promotes
unchanged. Requires a container runtime (caller's rights isn't in the warehouse
runtime).
"""

import pandas as pd
import streamlit as st

CTX_SQL = 'SELECT CURRENT_USER() AS "USER", CURRENT_ROLE() AS "ROLE"'

st.set_page_config(page_title="Owner's vs Caller's Rights", layout="wide")
st.title("Owner's rights vs. restricted caller's rights")
st.caption("Same app, same query, two connections. The row access + masking policies decide what each side sees.")

# Owner's-rights connection. Its current database is the app's own database, so
# we resolve the environment from it and query that env's DATA schema. This is
# what makes the app portable across dev and prod without code changes.
owner_conn = st.connection("snowflake")
ENV_DB = owner_conn.query("SELECT CURRENT_DATABASE() AS DB", ttl=0)["DB"][0]
TABLE = f"{ENV_DB}.DATA.SALES_BY_REGION"
DATA_SQL = f"SELECT region, rep, deal, amount, closed_on FROM {TABLE} ORDER BY region, closed_on"

st.caption(f"Environment: **{ENV_DB}**")

# Caller's-rights setup, run on the same cursor as each query so the warehouse
# and secondary roles are active in that session.
CALLER_SETUP = ("USE SECONDARY ROLES ALL", "USE WAREHOUSE KS_WH")


def show_owner(conn):
    st.dataframe(conn.query(CTX_SQL, ttl=0), hide_index=True, use_container_width=True)
    rows = conn.query(DATA_SQL, ttl=0)
    st.metric("Rows visible", len(rows))
    st.dataframe(rows, hide_index=True, use_container_width=True)


def run_caller_df(conn, sql):
    cur = conn.cursor()
    try:
        for stmt in CALLER_SETUP:
            cur.execute(stmt)
        cur.execute(sql)
        cols = [c[0] for c in cur.description]
        return pd.DataFrame(cur.fetchall(), columns=cols)
    finally:
        cur.close()


def show_caller(conn):
    st.dataframe(run_caller_df(conn, CTX_SQL), hide_index=True, use_container_width=True)
    rows = run_caller_df(conn, DATA_SQL)
    st.metric("Rows visible", len(rows))
    if rows.empty:
        st.info("You don't have access to any region's data.")
    st.dataframe(rows, hide_index=True, use_container_width=True)


left, right = st.columns(2, gap="large")

with left:
    st.subheader("Owner's rights")
    st.code('conn = st.connection("snowflake")', language="python")
    st.markdown("Runs as the **app owner** — sees every row, unmasked.")
    show_owner(owner_conn)

with right:
    st.subheader("Restricted caller's rights")
    st.code('conn = st.connection("snowflake-callers-rights")', language="python")
    st.markdown("Runs as the **viewer** — filtered by row access policy, rep masked.")
    try:
        caller_conn = st.connection("snowflake-callers-rights")
        show_caller(caller_conn)
    except Exception as exc:  # noqa: BLE001 — surface the real error in the UI
        st.warning("Caller's-rights query failed (needs container runtime + Streamlit 1.53+):")
        st.exception(exc)

with st.expander("What's happening here?"):
    st.markdown(
        """
- **Owner's rights** (`st.connection("snowflake")`) executes with the app
  owner's role. `CURRENT_ROLE()` is always the owner, so the policies grant a
  full, unmasked view.
- **Restricted caller's rights** (`st.connection("snowflake-callers-rights")`)
  executes as the signed-in viewer. `CURRENT_USER()` is the viewer, so the row
  access policy filters to their entitled region and the masking policy hides
  the rep name.
- Broad app access is safe because the **data layer** — not the app grant —
  decides what each viewer sees.
        """
    )
