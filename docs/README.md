# The docs

## Why are we here?

This repository claims to focus on Streamlit, but (within a week of creating
it), I've already realized that's a misnomer. Instead, it should be said that it
demonstrates _how_ to create hierarchy and separate boundaries for data and
applications, all inside of a single Snowflake account. Regardless of the
application's runtime.

My colleagues and I talk to customers just about every day who are trying to
figure out the best way to share and evangelize applications (be it Streamlit,
Snowflake App Runtime, etc.) inside their org — how to get one in front of
everyone who needs it without accidentally showing everyone everything, and how
to do that without turning the whole thing into a governance project or without
reinventing RBAC.

We talk to engineering and business leaders who are struggling with striking a
balance between opening up access and authorship to Citizen Developers, and
ensuring both the integrity and governance of data across these sprawling
application libraries. **These docs are written for those people** — the ones
who govern the account and enable everyone else, not the citizen developers
themselves. Citizen developers show up throughout, but as the people you're
enabling.

This repo is my answer, and it doubles as a home for the practices that tend to
come up in the same breath: 
- Creating a scalable and sustainable role hierarchy that supports data
governance and application visibility & development
- Giving analysts and DEs a sane local-dev loop
- Wiring up CI/CD so nobody is hand-deploying to prod at 5pm on a Friday

Here, we attempt to demonstrate best practices without oversimplifying: 

Picture a sales org with one modest table — `SALES_BY_REGION` — and a handful of
people who want to look at it: East reps who should see East, West reps who
should see West, and leadership who gets the whole picture. Someone builds a
Streamlit app to show it off, it works, and then everyone else wants one too.

That's the moment the real question shows up, and it's never "how do I write the
app?" — it's "how do I let everyone *open* it without letting everyone *see
everything*?" These docs walk through one answer to that question, built out in
full so you can read it, run it, and steal the parts you like: a role hierarchy
that shares broadly but governs at the data layer, the owner's-rights vs.
caller's-rights trick that makes it safe, and the CI/CD that promotes it through
environments on its own.

Is this meant to be a copy-pasta solution to your current situation? If only
life were that easy. These are - at their heart - reference architectures that
you (or your LLM) can take and run with.

## Next Up

[**Role hierarchy, environments & governance**](01-rbac.md) — who gets to touch
what.
