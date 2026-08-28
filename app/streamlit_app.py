"""
Owner's rights vs. restricted caller's rights — side by side.

The same query runs through two connections in one app:

  * Owner's rights            -> st.connection("snowflake")
  * Restricted caller's rights -> st.connection("snowflake-callers-rights")

A row access policy on SALES_BY_REGION does the rest: the owner role gets a full
view, while a caller is filtered to the region entitled to them in
USER_REGION_MAP. Requires a container runtime (caller's rights aren't available
in the warehouse runtime).
"""

import pandas as pd
import streamlit as st

TABLE = "KITCHEN_SINK_DEV.APPS.SALES_BY_REGION"
DATA_SQL = f"SELECT region, rep, deal, amount, closed_on FROM {TABLE} ORDER BY region, closed_on"
CTX_SQL = 'SELECT CURRENT_USER() AS "USER", CURRENT_ROLE() AS "ROLE"'

st.set_page_config(page_title="Owner's vs Caller's Rights", layout="wide")
st.title("Owner's rights vs. restricted caller's rights")
st.caption("Same app, same query, two connections. The row access policy decides what each side sees.")


def show_owner(conn):
    st.dataframe(conn.query(CTX_SQL, ttl=0), hide_index=True, use_container_width=True)
    rows = conn.query(DATA_SQL, ttl=0)
    st.metric("Rows visible", len(rows))
    st.dataframe(rows, hide_index=True, use_container_width=True)


def run_caller_df(conn, sql, setup):
    """Run session setup + a query on a single cursor so the warehouse and
    secondary roles are active in the same session as the query."""
    cur = conn.cursor()
    try:
        for stmt in setup:
            cur.execute(stmt)
        cur.execute(sql)
        cols = [c[0] for c in cur.description]
        return pd.DataFrame(cur.fetchall(), columns=cols)
    finally:
        cur.close()


def show_caller(conn, setup):
    st.dataframe(run_caller_df(conn, CTX_SQL, setup), hide_index=True, use_container_width=True)
    rows = run_caller_df(conn, DATA_SQL, setup)
    st.metric("Rows visible", len(rows))
    st.dataframe(rows, hide_index=True, use_container_width=True)


# The caller's-rights token is minted at session start; create the connection at
# the top of the script.
owner_conn = st.connection("snowflake")

# Caller's-rights setup, applied on the same cursor as each query:
#  - USE SECONDARY ROLES ALL activates the viewer's business roles (KS_SALES_*)
#    so they hold SELECT on the table (caller's rights is an intersection of the
#    viewer's privileges and the owner's caller grants).
#  - USE WAREHOUSE selects a warehouse (the caller's-rights session has none;
#    only the owner's-rights connection inherits the app's QUERY_WAREHOUSE).
CALLER_SETUP = ("USE SECONDARY ROLES ALL", "USE WAREHOUSE KS_WH")

left, right = st.columns(2, gap="large")

with left:
    st.subheader("Owner's rights")
    st.code('conn = st.connection("snowflake")', language="python")
    st.markdown("Runs as the **app owner** — sees every row.")
    show_owner(owner_conn)

with right:
    st.subheader("Restricted caller's rights")
    st.code('conn = st.connection("snowflake-callers-rights")', language="python")
    st.markdown("Runs as the **viewer** — filtered by the row access policy.")
    try:
        caller_conn = st.connection("snowflake-callers-rights")
        show_caller(caller_conn, CALLER_SETUP)
    except Exception as exc:  # noqa: BLE001 — surface the real error in the UI
        st.warning("Caller's-rights query failed (needs container runtime + Streamlit 1.53+):")
        st.exception(exc)

with st.expander("What's happening here?"):
    st.markdown(
        """
- **Owner's rights** (`st.connection("snowflake")`) executes with the app
  owner's role. `CURRENT_ROLE()` is always the owner, so the row access policy
  grants a full view.
- **Restricted caller's rights** (`st.connection("snowflake-callers-rights")`)
  executes as the signed-in viewer. `CURRENT_USER()` is the viewer, so the
  policy filters to the region entitled to them in `USER_REGION_MAP`.
- Broad app access (everyone can open this app) is safe because the **data
  layer** — not the app grant — decides what each viewer sees.
        """
    )
