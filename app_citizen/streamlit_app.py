"""
Citizen-developer sandbox — the fence is the grant.

An owner's-rights Streamlit owned by a business role (KS_SALES_EAST /
KS_SALES_WEST). It runs as that role for every viewer, so what it can read is
exactly what the role has been granted SELECT on: its own team's
SANDBOX.<team>.SALES. It holds no grant on the sibling team's table, so the
attempt to read that one fails — the boundary holding, live, with no row access
policy involved.

Contrast with the curated rights demo (app/streamlit_app.py): there, one broadly
shared app runs with restricted caller's rights and a row access policy decides
what each viewer sees. Here, many small apps each run as their owner and the
owner's own grants are the whole boundary.
"""

import streamlit as st

st.set_page_config(page_title="Citizen-dev sandbox", layout="wide")

conn = st.connection("snowflake")
ctx = conn.query(
    'SELECT CURRENT_USER() AS "USER", CURRENT_ROLE() AS "ROLE", '
    'CURRENT_DATABASE() AS "DB", CURRENT_SCHEMA() AS "SCHEMA"',
    ttl=0,
)
team = ctx["SCHEMA"][0]
sibling = "WEST" if team == "EAST" else "EAST"

st.title(f"{team} sandbox")
st.caption(
    "An owner's-rights app owned by this team's business role. It runs as that "
    "role for everyone who opens it, so the data boundary is the role's own "
    "SELECT grants — not a policy."
)
st.dataframe(ctx, hide_index=True, use_container_width=True)

left, right = st.columns(2, gap="large")

with left:
    st.subheader(f"Reading SANDBOX.{team}.SALES")
    st.markdown("The role holds `SELECT` here — this is the data it's *privy to*.")
    rows = conn.query(
        "SELECT region, rep, deal, amount, closed_on FROM SALES ORDER BY closed_on",
        ttl=0,
    )
    st.metric("Rows visible", len(rows))
    st.dataframe(rows, hide_index=True, use_container_width=True)

with right:
    st.subheader(f"Reaching for SANDBOX.{sibling}.SALES")
    st.markdown("The role has **no grant** here. The query should fail — that's the fence.")
    try:
        other = conn.query(
            f"SELECT region, rep, deal, amount, closed_on FROM SANDBOX.{sibling}.SALES",
            ttl=0,
        )
        st.error("Uh oh — this should not have been readable.")
        st.dataframe(other, hide_index=True, use_container_width=True)
    except Exception as exc:  # noqa: BLE001 — surfacing the denial is the point
        st.success("Access denied, as intended — the grant is the boundary.")
        st.exception(exc)

with st.expander("Why this is safe without a god-role"):
    st.markdown(
        """
- The app runs with **owner's rights**, as this team's business role, for every
  viewer — `CURRENT_ROLE()` above is that role, never the visitor's.
- `CREATE STREAMLIT` let the citizen dev *build* the app; it granted no data.
- What the app can read is fixed by the role's `SELECT` grants — its own team's
  table only. It can *name* the sibling team's table, but not read it.
- The sandbox schema is **managed access**, so the builder owns this app but
  can't `GRANT USAGE` on it. Sharing is the schema owner's decision.
        """
    )
