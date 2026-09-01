/*
 * ============================================================================
 * Phase 4 · 40_citizen_dev/01_sandbox_data.sql  —  Per-team sandbox data
 * ============================================================================
 *
 * Run once per team:
 *   snow sql -D team=EAST -D role=KS_SALES_EAST -f sql/40_citizen_dev/01_sandbox_data.sql
 *   snow sql -D team=WEST -D role=KS_SALES_WEST -f sql/40_citizen_dev/01_sandbox_data.sql
 *
 * Each team gets its OWN small SALES table in its OWN schema, and SELECT is
 * granted ONLY to that team's role. No row access policy, no masking — the
 * object grant itself is the fence. KS_SALES_EAST can read SANDBOX.EAST.SALES,
 * and holds no grant that would let it read SANDBOX.WEST.SALES.
 *
 * (In production a citizen dev would simply build on the grants their business
 * role already holds; here we stand up self-contained data so the boundary is
 * obvious in isolation, without entangling the curated row access / masking
 * policies from Phase 2.)
 *
 * The seed rows are the same demo data as the curated SALES_BY_REGION table;
 * each run inserts only its own team's rows (WHERE region = '<% team %>').
 *
 * Idempotent.
 * ============================================================================
 */

USE ROLE SYSADMIN;
USE WAREHOUSE KS_WH;
USE SCHEMA SANDBOX.<% team %>;

CREATE OR REPLACE TABLE SALES (
  region     VARCHAR,
  rep        VARCHAR,
  deal       VARCHAR,
  amount     NUMBER(12,2),
  closed_on  DATE
);

INSERT INTO SALES (region, rep, deal, amount, closed_on)
SELECT * FROM VALUES
  ('EAST', 'Ada',  'Acme Corp', 120000.00, '2026-01-14'),
  ('EAST', 'Ada',  'Globex',     84000.00, '2026-02-03'),
  ('EAST', 'Ben',  'Initech',    56000.00, '2026-02-19'),
  ('WEST', 'Cleo', 'Umbrella',  210000.00, '2026-01-27'),
  ('WEST', 'Cleo', 'Soylent',    73000.00, '2026-02-11'),
  ('WEST', 'Drew', 'Hooli',     145000.00, '2026-03-02')
  AS v(region, rep, deal, amount, closed_on)
WHERE region = '<% team %>';

-- The fence: SELECT goes only to this team's role. In the managed-access schema,
-- SYSADMIN (the schema owner) is the role that grants it.
GRANT SELECT ON TABLE SANDBOX.<% team %>.SALES TO ROLE <% role %>;
