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

import streamlit as st

TABLE = "KITCHEN_SINK_DEV.APPS.SALES_BY_REGION"
DATA_SQL = f"SELECT region, rep, deal, amount, closed_on FROM {TABLE} ORDER BY region, closed_on"
CTX_SQL = "SELECT CURRENT_USER() AS \"USER\", CURRENT_ROLE() AS \"ROLE\""

st.set_page_config(page_title="Owner's vs Caller's Rights", layout="wide")
st.title("Owner's rights vs. restricted caller's rights")
st.caption("Same app, same query, two connections. The row access policy decides what each side sees.")

# Create both connections at the top of the script: the caller's-rights token is
# only valid for ~2 minutes and is minted at session start.
owner_conn = st.connection("snowflake")

caller_conn = None
caller_error = None
try:
    caller_conn = st.connection("snowflake-callers-rights")
    # The viewer's DEFAULT role is active under caller's rights. Activate their
    # other granted roles (e.g. KS_SALES_*) so they actually hold SELECT on the
    # table — caller's rights is an intersection of the viewer's privileges and
    # the owner's caller grants. ttl=0 keeps this session-scoped (never cached).
    caller_conn.query("USE SECONDARY ROLES ALL", ttl=0)
except Exception as exc:  # noqa: BLE001 — surface any wiring issue in the UI
    caller_error = str(exc)


def show_side(conn, sql):
    ctx = conn.query(CTX_SQL, ttl=0)
    st.dataframe(ctx, hide_index=True, use_container_width=True)
    rows = conn.query(sql, ttl=0)
    st.metric("Rows visible", len(rows))
    st.dataframe(rows, hide_index=True, use_container_width=True)


left, right = st.columns(2, gap="large")

with left:
    st.subheader("Owner's rights")
    st.code('conn = st.connection("snowflake")', language="python")
    st.markdown("Runs as the **app owner** — sees every row.")
    show_side(owner_conn, DATA_SQL)

with right:
    st.subheader("Restricted caller's rights")
    st.code('conn = st.connection("snowflake-callers-rights")', language="python")
    st.markdown("Runs as the **viewer** — filtered by the row access policy.")
    if caller_conn is not None:
        show_side(caller_conn, DATA_SQL)
    else:
        st.warning(
            "Caller's-rights connection unavailable. This requires a container "
            "runtime and Streamlit 1.53+."
        )
        if caller_error:
            st.caption(caller_error)

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
