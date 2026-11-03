"""A permissive runner policy must never weaken the release gate."""
import copy
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    'verify_release', Path(__file__).resolve().parents[1] / 'scripts/verify-release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleasePolicyTests(unittest.TestCase):
    image = 'example.azurecr.io/hybrid-demo@sha256:' + 'a' * 64

    def policy(self):
        return {'version': '1.0', 'trustPolicies': [{
            'name': 'release', 'registryScopes': ['example.azurecr.io/hybrid-demo'],
            'signatureVerification': {'level': 'strict'},
            'trustedIdentities': ['x509.subject: CN=Test Release Signer'],
            'trustStores': ['ca:approved'],
        }]}

    def test_strict_scoped_policy_accepted(self):
        release.validate_policy(self.policy(), self.image)

    def test_permissive_policy_variants_rejected(self):
        variants = [
            ('registryScopes', ['*']),
            ('trustedIdentities', ['*']),
            ('trustedIdentities', []),
            ('trustStores', []),
            ('signatureVerification', {'level': 'permissive'}),
            ('signatureVerification', {'level': 'strict', 'override': {'expiry': 'skip'}}),
        ]
        for field, value in variants:
            with self.subTest(field=field, value=value):
                policy = self.policy()
                policy['trustPolicies'][0][field] = value
                with self.assertRaises(ValueError):
                    release.validate_policy(policy, self.image)
        policy = self.policy()
        policy['trustPolicies'].append(copy.deepcopy(policy['trustPolicies'][0]))
        with self.assertRaises(ValueError):
            release.validate_policy(policy, self.image)

    def test_mutable_image_tag_rejected(self):
        with self.assertRaises(ValueError):
            release.validate_policy(self.policy(), 'example.azurecr.io/hybrid-demo:latest')
