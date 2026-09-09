# Graduation: when a sandbox app grows up

The [previous chapter](04-citizen-developers.md) ended on a happy problem. A
citizen developer built something in a sandbox, on their own data, and it turned
out to be *good* — good enough that word got around and now leadership wants it
in front of the whole org. So what do you do?

The tempting answer is the wrong one. You do **not** widen the share on the
sandbox app. That app runs with owner's rights, as the builder's role, so
granting it to everyone hands every viewer the builder's data — the exact leak
[chapter two](02-rights-model.md) spent its whole length warning about. "Share
it wider" is how a good idea becomes an incident.

The real answer is that promotion is a **re-platforming** — you
move the idea out of the incubator and rebuild it inside the curated model from
the first three chapters. The good news: you've already built everything it
needs to land in. This chapter is the bridge between the two ends of the repo,
and the nice part is you can read it as a literal diff between two files that
already exist: [`app_citizen/streamlit_app.py`](../app_citizen/streamlit_app.py)
on the left, [`app/streamlit_app.py`](../app/streamlit_app.py) on the right.

## Promotion isn't `GRANT OWNERSHIP`

The sandbox app and a curated app differ on nearly every axis at once. That's
why there's no one-line promotion — you're changing the whole shape:

| Axis | Sandbox (`app_citizen/`) | Promoted (`app/` + ch. 1–3) |
|------|--------------------------|-----------------------------|
| Rights model | Owner's rights, runs as the business role | Restricted caller's rights, runs as the viewer |
| Data boundary | Object grant on its own team's table | Row access policy + masking on the governed table |
| Data source | `SANDBOX.<team>.SALES` | `KITCHEN_SINK_<env>.DATA.SALES_BY_REGION` |
| Owner | `KS_SALES_EAST` | `KS_APP_STAGING` / `KS_APP_OWNER_PROD` |
| Source of truth | A workspace, no Git | Git repo, in the CI/CD pipeline |
| Sharing | Schema owner → the one team | `KS_STREAMLIT_VIEWER` → everyone |
| Lifecycle | Ephemeral, drop it anytime | Staging rehearsal, gated prod deploy, on call |

Read top to bottom, that's the definition of "business-critical." The sandbox
was an **incubator**; graduation is the platform team *adopting* the proven idea
and re-homing it. The Python often survives nearly intact — it's the governance
wrapper around it that gets replaced wholesale.

## The fork that picks the target: what does everyone see?

Before any of the mechanics, one question decides which model you promote
*into*:

- **Per-viewer-sensitive** — East should see East, West should see West. Then
the promoted app must run with **restricted caller's rights** so each viewer
executes as themselves, and the [row access policy](02-rights-model.md) does the
filtering. This is the harder path, and it's the one most "share it with
everyone" ideas actually need.
- **Uniform and non-sensitive** — an aggregate dashboard everyone is meant to
see identically. Then it can *stay* owner's rights, but ownership moves off the
builder's broad business role and onto a **narrow, purpose-built app-owner
role** that holds exactly the intended-public grants. No policy required; the
boundary becomes "what that dedicated role can see."

Get this wrong in the safe direction and you leak nothing; get it wrong in the
unsafe direction and you're back to the incident. When in doubt, assume
per-viewer-sensitive.

## The move, column to column

Taking the per-viewer-sensitive path, here's the sandbox
app becoming the curated app, piece by piece. Every piece on the right already
exists in this repo:

- **Repoint the data.** The sandbox app reads `SANDBOX.<team>.SALES`, a
self-contained partition it was granted. The promoted app reads the governed
[`KITCHEN_SINK_<env>.DATA.SALES_BY_REGION`](../sql/10_demo_data/01_sales_table.sql)
instead — the same table the rest of the repo governs.
- **Flip the rights model.** The sandbox app uses one owner's-rights connection
(`st.connection("snowflake")`). The promoted app adds the
`snowflake-callers-rights` connection and queries through it, which means it now
needs the container runtime and `streamlit>=1.53` — exactly the setup in
[`app/snowflake.yml`](../app/snowflake.yml) and
[`app/pyproject.toml`](../app/pyproject.toml).
- **Adopt the governance you already have.** The [row access policy and masking
policy](../sql/10_demo_data/03_row_access_policy.sql) and the [caller
grants](../sql/20_caller_grants/01_caller_grants.sql) don't get rebuilt — the
promoted app simply lands on top of them. This is the payoff of keeping
governance in the data layer: the app graduates, the policies don't move.
- **Re-own it.** The object stops being owned by `KS_SALES_EAST` and becomes
owned by `KS_APP_STAGING` (then `KS_APP_OWNER_PROD`). It can't stay owned by the
business role — that would drag the owner's-rights leak right back in.
- **Enter the pipeline.** The code leaves the workspace and becomes a tracked
artifact deployed by [CI/CD](03-cicd.md): staging on merge, prod behind the
gate.
- **Share broadly, then decommission.** `GRANT USAGE … TO ROLE
KS_STREAMLIT_VIEWER`, and drop the sandbox Streamlit. The incubator did its job.

The promoted app is a **different deployed
object**, not the sandbox object with a setting toggled. You don't flip a
Streamlit from owner's rights to caller's rights in place — you deploy the
curated version into `KITCHEN_SINK_*.APPS` and retire the sandbox one. The logic
carries; the shell is rebuilt.

## The seams (where this actually gets hard)

- **The code rarely survives untouched.** A sandbox app written to run as an
owner over its own table quietly assumes "I can see everything in here." Under
caller's rights that assumption breaks — it has to tolerate filtered and empty
results, masked columns, and the [secondary-role behavior](02-rights-model.md)
that decides what the viewer's session can actually reach. That's real rework,
and it's where a careless promotion leaks.
- **The workspace → Git handoff.** The citizen dev deliberately opted out of
Git. Productionizing opts the *code* back in — someone lifts it out of the
workspace into the repo, and from then on it lives under version control like
everything else.
- **Authorship changes hands.** After promotion the app is owned by a platform
role, not the builder. That's a governance win, but socially it's "your baby now
belongs to the platform team." Better to say so up front than to surprise
someone with it.
- **There's a gate.** "Deemed worthy" implies a decision — a lightweight intake
where a business sponsor and the platform team agree this earns a spot in the
pipeline. It's the idea-level cousin of the `promote-prod` approval from the
[CI/CD chapter](03-cicd.md): the pipeline waits for a human to say "yes, this
one graduates."

## If you've already opened the gates

Everything above assumes you're building the on-ramp before the traffic. Plenty
of orgs arrive the other way around — citizen developers already went wide, and
there's a pile of Streamlit apps nobody's sure about. Retrofitting that sprawl
is its own project and mostly outside what this repo can hand you, but the
triage is simple enough to state:

- **Take inventory.** `SHOW STREAMLITS IN ACCOUNT;` gets you every app, its
owner role, and where it lives; `SHOW GRANTS ON STREAMLIT <fqn>;` tells you who
it's shared to. Owner's rights + a broad share is the combination to look at
first.
- **Sort each app into one of three buckets:**
  - **Promote** — people depend on it and it's shared beyond its owner's data;
  run it through this chapter.
  - **Leave in the sandbox** — genuinely personal or team-local; fine as-is
  under the [ch. 4](04-citizen-developers.md) model.
  - **Retire** — nobody's opened it in a quarter; drop it.

That's a rubric, not a migration tool — but it's enough to stop the bleeding and
point each app at the right end of the spectrum.

## Next Up

That closes the conceptual loop. The repo now covers the whole arc: a [role
hierarchy](01-rbac.md) that shares broadly and governs at the data layer, the
[rights model](02-rights-model.md) that makes it safe, the [CI/CD](03-cicd.md)
that promotes the curated apps, a [citizen-dev
sandbox](04-citizen-developers.md) for the ideas that haven't earned all that
yet — and this chapter, the on-ramp between the two.

Which leaves one question: convinced, but where do you actually start? The [next
chapter](06-implementation.md) turns all of this into a phased rollout plan — a
doing-order with a demoable win and a retrospective you can check off at every
milestone, so you can show progress from the first week without betting the
company on a big-bang migration. Or head back to the [docs index](README.md) and
go read the code; at this point the left and right columns should both look
familiar.
