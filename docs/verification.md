# Verification report

Date: 3 November 2026. Scope: paid private architecture on `hardening/private-architecture`. No Azure resources were created or modified, and no Cisco interoperability test was performed. The user has no licensed Cisco lab and requested a plan before deployment.

## Results

| Check | Result |
| --- | --- |
| Terraform formatting | Passed |
| Backend-disabled provider initialization and validation | Dev and prod passed |
| Mocked Terraform plan assertions | Dev and prod passed under Terraform 1.9.8; five security assertions in each plan |
| TFLint | Dev and prod passed with AzureRM rules 0.27.0 |
| Python tests | Nine tests passed on host Python 3.13 and container Python 3.12 |
| HTTP behavior | Liveness 200; readiness 503 for absent/empty secret, 200 for a populated temporary mount, then 503 after removal; unknown path 404; secret value absent from responses |
| Strict signing-policy tests | Exact repository and digest accepted; wildcard scope/signer, empty signer/trust store, permissive verification, expiry-skip override, extra rule and mutable tag rejected |
| Python compilation / shell syntax | Passed |
| YAML / Helm | Workflows parse; chart lint passed; rendered digest and application node selector checked |
| Docker build | Passed on Python 3.12 / Alpine 3.23; detected Alpine 3.23.7 |
| Trivy image scan | Zero HIGH/CRITICAL findings; [image report](image-scan.json), Trivy 0.76.1 |
| Checkov Terraform scan | 131 passed, 2 failed, 0 skipped, 0 parsing errors across 111 resource definitions; [findings](checkov-results.json) |
| Live saved Azure plan | Not created; real DES, administrator, backend, runner and Cisco peer inputs remain outstanding |
| Regional node SKU lookup | Host encryption, ephemeral disks and 150-GiB local storage advertised; current subscription restricts zones 1 and 3 in West Europe; actual allocation untested |
| Azure provisioning / AKS CSI / VPN and BGP | Not verified; no deployment performed |
| Real image signature, quarantine release and admission policy | Not verified; security bootstrap and live negative tests required |

Terraform uses AzureRM 3.117.1 and AzureAD 2.53.1 with committed provider locks. Signed package hashes are recorded for Linux AMD64, macOS AMD64 and macOS ARM64 so readonly CI initialization can verify its installed packages. Final full-toolchain verification used Terraform 1.9.8, matching CI, TFLint 0.57.0, Helm 3.18.4, Checkov 3.4.3 and PyYAML 6.0.3. The pinned provider emits deprecation warnings for its old subnet-policy and managed-Entra arguments; these are warnings, not validation errors. The Entra flag remains true as required by that provider.

The full local script exits nonzero at its final security check. Passing the earlier checks does not mean the full security gate is green. Lower-severity image findings were outside the requested HIGH/CRITICAL scan and are not claimed absent.

GitHub-hosted Linux verification for code commit `af3c20c` passed Python/shell/format checks, both environment Terraform validation/mock-plan/TFLint jobs, Helm and image vulnerability scanning. Only the two documented Checkov findings failed. [Verification run](https://github.com/krishnagmx/azure-hub-spoke-cisco/actions/runs/41709041250). Signed cross-platform provider hashes and authenticated TFLint release downloads resolved the initial hosted-runner failures. Cloud planning was skipped because this remains a draft PR with unmet bootstrap dependencies.

## Hardening outcome

The original POC scan was 99 passed / 28 failed. Initial changes to Key Vault ACLs, firewall threat mode and AKS patch/max-pod settings reduced it to 24 findings. Following the user's choice of paid services/private networking, the review branch adds:

- Private Standard AKS with an explicit private DNS zone linked to all three VNets.
- Pre-created control-plane/kubelet identities, DNS and DES access before cluster creation, and registry pull access before nodes start.
- Separate critical-system and application node pools, host encryption, ephemeral OS disks and required external DES.
- Private, zone-redundant Premium ACR with geo-replication, retention and quarantine.
- Premium Firewall with IDPS Deny and threat intelligence Deny, explicit peer-spoke routes and shared-runner HTTPS access to private endpoints.
- Manual plan-only-by-default infrastructure workflow and digest-based app deployment from private runners.
- An exact-repository strict Notation policy check, signature verification and blocking vulnerability scan in app delivery.
- Credential-free CI for mocked plans, validation, TFLint, Helm, Python tests, Checkov and container vulnerability scanning.

The local image scan reports no HIGH/CRITICAL vulnerabilities for the image ID recorded in [image-scan.json](image-scan.json). It is a point-in-time database result; subsequent builds or database updates need a new scan.

## Remaining scanner gate

Only CKV_AZURE_164 remains, once per environment's registry. It checks legacy Docker Content Trust. Microsoft states that DCT cannot be enabled on new registries after 31 May 2026 and recommends a Notary Project signing/verification replacement. [Microsoft guidance](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-content-trust-deprecation)

No suppression or blanket exemption was added. The replacement workflow code does not establish a working certificate authority, signing process, quarantine release or admission policy by itself. A security reviewer must validate those dependencies and live rejection cases before deciding on an individually scoped legacy-policy exemption. Checkov's ACR vulnerability rule checks the SKU only; the separate Trivy scan is actual image-scanning evidence, and subscription-wide Defender remains a bootstrap requirement.

## Reproduce

Install the versions above, activate a virtual environment containing `checkov==3.4.3` and `PyYAML==6.0.3`, and run:

```bash
./scripts/validate-local.sh
terraform -chdir=environments/dev test -var-file=config.tfvars
terraform -chdir=environments/prod test -var-file=config.tfvars
```

The script runs from the repository root regardless of the caller's directory. Initialization requires provider/plugin network access; tests use a loopback port. The Terraform tests use mocked providers, documentation IPs and fabricated IDs and must never be mistaken for a cloud deployment plan.

To repeat the image scan:

```bash
docker build -t hybrid-demo:private-review app
trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 1 hybrid-demo:private-review
```

Read-only Azure inventory found no deployed `hybridlz-dev-rg` or `hybridlz-prod-rg`. Existing `akspoc-rg` resources were not changed. Initial cloud GitHub workflows failed at Azure login because repository OIDC secrets/variables are not configured; GitHub authentication for publishing is separate from Azure authorization. The paid review changes do not trigger automatic applies.

See the [deployment plan](deployment-plan.md) for bootstrap order, recurring cost drivers, plan approval and acceptance evidence. Full hybrid verification remains blocked until a licensed Cisco lab and real peer address exist.
