# The docs

I talk to customers just about every day who are trying to figure out the best way
to share and evangelize Streamlit apps inside their org — how to get one in front of
everyone who needs it without accidentally showing everyone everything, and how to do
that without turning the whole thing into a governance science project. This repo is
my answer, and it doubles as a home for the practices that tend to come up
in the same breath: giving analysts and DEs a sane local-dev loop, and wiring up CI/CD
so nobody is hand-deploying to prod at 5pm on a Friday.

Picture a sales org with one modest table — `SALES_BY_REGION` — and a handful of
people who want to look at it: East reps who should see East, West reps who should
see West, and leadership who gets the whole picture. Someone builds a Streamlit app
to show it off, it works, and then everyone else wants one too. That's the moment
the real question shows up, and it's never "how do I write the app?" — it's "how do
I let everyone *open* it without letting everyone *see everything*?" These docs walk
through one answer to that question, built out in full so you can read it,
run it, and steal the parts you like: a role hierarchy that shares broadly but
governs at the data layer, the owner's-rights vs. caller's-rights trick that makes
it safe, and the CI/CD that promotes it through environments on its own.

Read in order:

1. [**Role hierarchy, environments & governance**](01-rbac.md) — who gets to touch what.
2. [**Owner's rights vs. restricted caller's rights**](02-rights-model.md) — the same query, two very different views.
3. [**CI/CD and environment promotion**](03-cicd.md) — code goes up, data comes down.
