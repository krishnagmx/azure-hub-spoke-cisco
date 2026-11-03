#!/usr/bin/env python3
"""Verify a digest with an explicit strict Notation policy, then scan it."""
import json
import os
import re
import subprocess
import sys
from pathlib import Path


def validate_policy(policy, image):
    if not re.fullmatch(r"[a-z0-9]+\.azurecr\.io/hybrid-demo@sha256:[a-f0-9]{64}", image):
        raise ValueError("Expected an ACR hybrid-demo image pinned by SHA256 digest")
    repository = image.split('@', 1)[0]
    rules = policy.get('trustPolicies', [])
    # Require a single exact repository rule: no permissive fallback or wildcard scope.
    if len(rules) != 1 or rules[0].get('registryScopes') != [repository]:
        raise ValueError("Notation policy must contain one exact repository-scoped rule")
    rule = rules[0]
    verification = rule.get('signatureVerification', {})
    if verification.get('level') != 'strict' or verification.get('override'):
        raise ValueError("Notation verification must be strict with no overrides")
    identities = rule.get('trustedIdentities', [])
    if not identities or any('*' in identity for identity in identities):
        raise ValueError("Explicit signer identities are required; wildcards are forbidden")
    if not rule.get('trustStores'):
        raise ValueError("An approved certificate trust store is required")


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: verify-release.py REGISTRY.azurecr.io/hybrid-demo@sha256:DIGEST")
    image = sys.argv[1]
    config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config'))
    policy = json.loads((config / 'notation' / 'trustpolicy.json').read_text())
    validate_policy(policy, image)
    subprocess.run(['notation', 'verify', image], check=True)
    subprocess.run(['trivy', 'image', '--scanners', 'vuln', '--exit-code', '1',
                    '--severity', 'HIGH,CRITICAL', image], check=True)


if __name__ == '__main__':
    main()
