# Verification report

Date: 3 November 2026. Verification applies to the source delivered with this report. Local checks do not establish successful Azure provisioning or Cisco interoperability.

## Results

| Check | Result |
| --- | --- |
| Terraform recursive formatting | Passed after formatting 14 files |
| Backend-disabled init, dev and prod | Passed; provider lock files generated and included |
| Terraform validate, dev and prod | Passed with deprecated subnet-policy argument warnings |
| TFLint, dev and prod | Passed with the repository's AzureRM plugin |
| Python unittest | Six tests passed on host Python 3.13 and container Python 3.12; container test fixture uses a temporary writable `/tmp` |
| HTTP behavior | `/` and `/healthz` return 200; `/readyz` returns 503 for absent/empty secret, 200 for a populated mount, then 503 after removal; unknown path returns 404; secret value never appears in response |
| Python compilation and shell syntax | Passed |
| YAML parsing | Nine configuration files parsed |
| Helm lint | Passed; informational recommendation to add a chart icon |
| Helm template | Five Kubernetes resources rendered and parsed successfully |
| Docker build and runtime | Built `hybrid-demo:local-verify`; HTTP 200 liveness and HTTP 503 readiness without a secret mount under a read-only filesystem, dropped capabilities and no-new-privileges |
| Cisco rendering | Dev/prod rendered using synthetic documentation IPs and PSK; permissions checked as 0600; generated files removed |
| Checkov Terraform scan | Failed: 99 passed, 28 failed, zero skipped, zero parsing errors |
| Azure plan/apply and end-to-end VPN/BGP/AKS | Not run; deployment inputs and network prerequisites remain outstanding |

Tools: Terraform 1.15.5 on darwin_amd64, Python 3.13 on the host and Python 3.12 in Docker, TFLint 0.57.0 with AzureRM rules 0.27.0, Helm 3.18.4, Checkov 3.4.3 and PyYAML 6.0.3. GitHub workflows select Terraform 1.9.8; that Terraform version was not used for the local checks.

## Security gate

The committed [scanner summary](checkov-results.json) lists every failed check and its resource. The count includes duplicate findings for ACR in the two environments. No checks were suppressed, and CI continues to block on these findings.

Findings cover ACR data endpoints, redundancy, retention, image trust/quarantine/scanning and public access; AKS SLA tier, private API, encryption, node isolation, ephemeral disks, API allowlist, upgrades and max pods; Key Vault firewall settings; and Firewall IDPS/threat intelligence. Basic ACR, Free AKS and Standard Firewall are intentional POC cost choices, but this does not satisfy the scanner's production policies. Resolve policies through reviewed infrastructure changes or explicitly approved, individually justified exemptions before expecting green cloud CI. Changing SKUs or network isolation also requires reviewing cost and runner connectivity.

## Reproduce

Install Terraform, TFLint and Helm versions above. In a Python virtual environment install `checkov==3.4.3` and `PyYAML==6.0.3`, activate it, then run:

```bash
./scripts/validate-local.sh
```

The script runs from the repository root regardless of the caller's directory. Provider/plugin initialization requires internet access. It stops when Checkov reports findings. To inspect the remaining checks independently:

```bash
python3 -c 'import yaml; yaml.safe_load(open("cisco/containerlab.yaml"))'
helm lint helm/hybrid-demo --set azure.keyvaultName=a --set azure.workloadClientId=b --set azure.tenantId=c
```

## Remaining deployment verification

Supply a reachable Cisco public IPv4, a real VPN PSK through an environment variable or secret store, remote backend settings, and an AKS administrator Entra group. Follow README sections 2–6 to bootstrap state, configure OIDC, review a saved plan and deploy one environment. Do not substitute the synthetic renderer test inputs for deployment credentials.

On a licensed Linux x86_64 Cisco lab, prove IKEv2 and IPsec SAs, BGP establishment, learned routes and private VM HTTP traffic. On AKS, mount the real Key Vault secret and confirm rollout and `/readyz`. Capture sanitized command output before marking the README's end-to-end checkbox complete. No cloud resources were created during this local verification.
