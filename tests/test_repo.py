"""Fast stdlib tests. Run python3 -m unittest discover -s tests."""
import ipaddress
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

class ArchitectureInvariantTests(unittest.TestCase):
    def test_address_plan_no_overlap(self):
        prod = ["10.0.0.0/16", "10.10.0.0/16", "10.20.0.0/16", "172.16.10.0/24"]
        dev = ["10.100.0.0/16", "10.110.0.0/16", "10.120.0.0/16"]
        prefixes = [ipaddress.ip_network(c) for c in prod + dev]
        for i, a in enumerate(prefixes):
            for b in prefixes[i + 1:]:
                self.assertFalse(a.overlaps(b), (a, b))

    def test_bgp_constants_match(self):
        net = (ROOT / 'modules/network/variables.tf').read_text()
        ios = (ROOT / 'cisco/ios-xe-config.tftpl').read_text()
        for value in ('65010', '65020', '169.254.21.1', '169.254.21.2'):
            self.assertIn(value, net)
            self.assertIn(value, ios)

    def test_required_workflows(self):
        for x in ('terraform-pr', 'terraform-apply', 'drift-detection', 'app-deploy'):
            self.assertTrue((ROOT / f'.github/workflows/{x}.yml').is_file())

    def test_secret_files_untracked(self):
        ignore = (ROOT / '.gitignore').read_text()
        self.assertIn('cisco/generated/', ignore)
        self.assertIn('**/*.tfstate', ignore)
        self.assertIn('**/terraform.tfvars', ignore)

    def test_no_secret_resource_in_terraform(self):
        for f in ROOT.rglob('*.tf'):
            self.assertNotIn('resource "azurerm_key_vault_secret"', f.read_text())

if __name__ == '__main__':
    unittest.main()
