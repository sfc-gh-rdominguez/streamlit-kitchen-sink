#!/usr/bin/env python3
"""
Refresh the KS_DEPLOYER GitHub Actions network policy so the CI service user can
reach a VPN-restricted Snowflake account from GitHub-hosted runners. A user-level
network policy overrides the account policy for that user only.

Runs under the scoped KS_NETPOLICY_ADMIN role (owns the policy + rules). Uses
ALTER (not CREATE OR REPLACE) because the rules are in-use by the attached
policy and cannot be dropped/replaced while in use. Does NOT re-attach the policy
to the user — that is done once at setup — so it needs no privilege on the user.

Prints SQL to stdout. Apply with:
    python3 scripts/refresh_gh_actions_network_policy.py | snow sql -c <conn> -f /dev/stdin

CAVEATS
  - Allows all GitHub-hosted runner IPs (broad). The service user is still
    protected by key-pair auth + least-privilege roles. Prefer a self-hosted
    runner if you need narrow IPs.
  - GitHub rotates these ranges (~weekly); the weekly workflow re-runs this.
"""
import json
import urllib.request

CHUNK = 1000  # CIDRs per network rule
RULE_SCHEMA = "KITCHEN_SINK_PROD.PUBLIC"
RULE_PREFIX = "GH_ACTIONS_IPV4"
POLICY = "KS_DEPLOYER_GH_ACTIONS"
PLACEHOLDER = "192.0.2.0/24"  # TEST-NET-1; harmless value for a freshly-created chunk

meta = json.load(urllib.request.urlopen("https://api.github.com/meta", timeout=30))
ipv4 = [c for c in meta["actions"] if ":" not in c]
chunks = [ipv4[i:i + CHUNK] for i in range(0, len(ipv4), CHUNK)]

print("USE ROLE KS_NETPOLICY_ADMIN;")
rule_names = []
for i, chunk in enumerate(chunks, 1):
    name = f"{RULE_SCHEMA}.{RULE_PREFIX}_{i}"
    rule_names.append(name)
    values = ", ".join(f"'{c}'" for c in chunk)
    # CREATE IF NOT EXISTS handles new chunks (GitHub grew); ALTER updates the
    # value list in place, which is allowed even while the rule is in use.
    print(f"CREATE NETWORK RULE IF NOT EXISTS {name}")
    print(f"  MODE = INGRESS TYPE = IPV4 VALUE_LIST = ('{PLACEHOLDER}')")
    print(f"  COMMENT = 'GitHub Actions runner IPv4 ranges (chunk {i})';")
    print(f"ALTER NETWORK RULE {name} SET VALUE_LIST = ({values});")

# Ensure the policy references exactly the current set of rules (handles growth).
rule_list = ", ".join(f"'{n}'" for n in rule_names)
print(f"ALTER NETWORK POLICY {POLICY} SET ALLOWED_NETWORK_RULE_LIST = ({rule_list});")
