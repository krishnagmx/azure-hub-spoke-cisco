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
| Checkov Terraform scan | Failed: 103 passed, 24 failed, zero skipped, zero parsing errors; previous baseline was 99 passed / 28 failed |
| Azure plan/apply and end-to-end VPN/BGP/AKS | Not run; deployment inputs and network prerequisites remain outstanding |

Tools: Terraform 1.15.5 on darwin_amd64, Python 3.13 on the host and Python 3.12 in Docker, TFLint 0.57.0 with AzureRM rules 0.27.0, Helm 3.18.4, Checkov 3.4.3 and PyYAML 6.0.3. GitHub workflows select Terraform 1.9.8; that Terraform version was not used for the local checks.

## Security gate

Follow-up hardening added Key Vault deny-by-default network ACLs with no trusted-service bypass, threat intelligence `Deny` on both the Firewall and its policy, AKS automatic patch upgrades and an explicit 110-pod node limit. These changes resolved CKV_AZURE_109, CKV_AZURE_216, CKV_AZURE_171 and CKV_AZURE_168. Explicit peer-spoke UDRs now make the cross-spoke inspection path visible in each route table, and subnet associations wait for those routes. These changes have been validated locally, not applied in Azure.

The initial GitHub `Local checks` run passed. Initial Terraform Apply and AKS Application Delivery runs failed at Azure login because the newly created repository has no Azure OIDC secrets or repository variables. GitHub sign-in permits publishing code; it does not configure Azure deployment identities. The expanded `Local checks` workflow validates infrastructure without those identities and exposes the outstanding Checkov failures as a separate blocking job.

The committed [scanner summary](checkov-results.json) lists every failed check and its resource. The count includes duplicate findings for ACR in the two environments. No checks were suppressed, and CI continues to block on these findings.

Remaining findings cover ACR data endpoints, redundancy, retention, image trust/quarantine/scanning and public access; AKS SLA tier, private API, encryption, node isolation, ephemeral disks and API allowlist; and Firewall IDPS. Basic ACR, Free AKS and Standard Firewall are intentional POC cost choices, but this does not satisfy the scanner's production policies. Resolve policies through reviewed infrastructure changes or explicitly approved, individually justified exemptions before expecting green cloud CI. Changing SKUs or network isolation also requires reviewing cost and runner connectivity.

CKV_AZURE_164 recommends Docker Content Trust, but Microsoft states that it cannot be enabled on new registries after 31 May 2026. Follow the [Notary Project migration guidance](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-content-trust-deprecation) for image signing and admission verification instead. The legacy check remains unsuppressed; setting its Terraform boolean would not prove a working signature policy. Also, Checkov's CKV_AZURE_163 only checks the registry SKU; passing it alone would not prove Defender scanning is configured.

## Reproduce

Install Terraform, TFLint and Helm versions above. In a Python virtual environment install `checkov==3.4.3` and `PyYAML==6.0.3`, activate it, then run:

```bash
./scripts/validate-local.sh
```

The script runs from the repository root regardless of the caller's directory. Provider/plugin initialization requires internet access. It runs YAML and Helm checks before stopping when Checkov reports findings. To inspect those checks independently:

```bash
python3 -c 'import yaml; yaml.safe_load(open("cisco/containerlab.yaml"))'
helm lint helm/hybrid-demo --set azure.keyvaultName=a --set azure.workloadClientId=b --set azure.tenantId=c
```

## Remaining deployment verification

Supply a reachable Cisco public IPv4, a real VPN PSK through an environment variable or secret store, remote backend settings, and an AKS administrator Entra group. Follow README sections 2–6 to bootstrap state, configure OIDC, review a saved plan and deploy one environment. Do not substitute the synthetic renderer test inputs for deployment credentials.

On a licensed Linux x86_64 Cisco lab, prove IKEv2 and IPsec SAs, BGP establishment, learned routes and private VM HTTP traffic. On AKS, mount the real Key Vault secret and confirm rollout and `/readyz`. Capture sanitized command output before marking the README's end-to-end checkbox complete. No cloud resources were created during this local verification.

Read-only Azure inventory found no `hybridlz-dev-rg` or `hybridlz-prod-rg` deployment. An existing `akspoc-rg` belongs to a different project and was not changed. Local Docker has no licensed CSR image. Required external inputs remain: the Cisco lab host/user and reachable public IPv4, AKS administrator group IDs, and selected backend settings. The repository's Azure OIDC principals, environment protections, secrets and variables must then be bootstrapped according to README section 3. Keep real PSKs out of chat and Git; supply them through a secret store.
