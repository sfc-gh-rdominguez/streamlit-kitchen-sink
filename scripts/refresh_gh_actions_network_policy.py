#!/usr/bin/env python3
"""
Generate a user-scoped network policy for KS_DEPLOYER that allowlists GitHub
Actions runner IP ranges, so the CI service user can reach a VPN-restricted
Snowflake account. A user-level network policy overrides the account policy for
that user only.

Prints SQL to stdout. Apply with:
    python3 scripts/refresh_gh_actions_network_policy.py | snow sql -c <conn> -f /dev/stdin

CAVEATS
  - This allows every GitHub-hosted runner IP (broad). The service user is still
    protected by key-pair auth and least-privilege roles, but the IP allowlist is
    wide. Prefer a self-hosted runner if your security posture requires narrow IPs.
  - GitHub rotates these ranges (~weekly). Re-run this script on a schedule to
    keep the policy current, or CI will start failing as ranges drift.
"""
import json
import urllib.request

CHUNK = 1000  # CIDRs per network rule (stay well under limits)
RULE_SCHEMA = "KITCHEN_SINK_PROD.PUBLIC"
POLICY = "KS_DEPLOYER_GH_ACTIONS"
USER = "KS_DEPLOYER"

meta = json.load(urllib.request.urlopen("https://api.github.com/meta", timeout=30))
ipv4 = [c for c in meta["actions"] if ":" not in c]

chunks = [ipv4[i:i + CHUNK] for i in range(0, len(ipv4), CHUNK)]
rule_names = []

print("USE ROLE ACCOUNTADMIN;")
for i, chunk in enumerate(chunks, 1):
    name = f"{RULE_SCHEMA}.GH_ACTIONS_IPV4_{i}"
    rule_names.append(name)
    values = ", ".join(f"'{c}'" for c in chunk)
    print(f"CREATE OR REPLACE NETWORK RULE {name}")
    print(f"  MODE = INGRESS TYPE = IPV4 VALUE_LIST = ({values})")
    print(f"  COMMENT = 'GitHub Actions runner IPv4 ranges (chunk {i}); refresh weekly';")

rule_list = ", ".join(f"'{n}'" for n in rule_names)
print(f"CREATE OR REPLACE NETWORK POLICY {POLICY}")
print(f"  ALLOWED_NETWORK_RULE_LIST = ({rule_list})")
print("  COMMENT = 'Scoped to KS_DEPLOYER: allow GitHub Actions runners (overrides account VPN policy for this user only)';")
print(f"ALTER USER {USER} SET NETWORK_POLICY = {POLICY};")
