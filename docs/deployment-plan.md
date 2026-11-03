# Paid private architecture: review and deployment plan

Prepared on 3 November 2026 for `hardening/private-architecture`. Status: configuration and mocked plans prepared; **no cloud deployment is authorized by this document**. The user requested a plan before deployment and confirmed there is no Cisco lab.

This is an architecture and rollout plan, not an executable saved Terraform plan. A live plan cannot be produced honestly until the real DES, administrator group, state backend and reachable Cisco peer inputs are selected. The mocked plan tests use documentation IPs and fabricated IDs; they are not deployment artifacts.

## Proposed changes

| Area | Original POC | Prepared private architecture |
| --- | --- | --- |
| AKS | Free tier; public API | Standard tier; private API; public FQDN disabled |
| AKS DNS | Platform default | Explicit regional private zone linked to hub and both spokes; scoped DNS identity permission |
| Nodes | Two shared D2as_v5 nodes | Two D4ds_v5 system nodes reserved for critical addons, plus two D4ds_v5 application nodes |
| Node encryption | Default platform settings | Host encryption, 128-GiB ephemeral OS disks, required external DES for supported managed disks |
| Registry | Basic, public | Premium, public access disabled, private endpoint/DNS, zone redundancy, North Europe geo-replica, 7-day untagged retention |
| Image release | Build and deploy SHA tag | Quarantine new pushes; separate security-controlled scan/sign/release; manual deployment of a released digest with strict Notation and HIGH/CRITICAL vulnerability gates |
| Firewall | Standard, alerting | Premium with IDPS Deny and threat intelligence Deny |
| Key Vault | Private RBAC vault | Private RBAC vault plus deny-default ACLs; no service bypass for application vault |
| Deployment runners | Hosted | Dedicated private Linux x86_64 runner labeled `azure-private` |
| Apply | Push-triggered | Manual, plan-only default; apply requires explicit input, main branch, security pass and protected environment |
| Quality gates | Cloud-authenticated checks | Credential-free Terraform validation, mock policy plans, TFLint, Helm, Python and blocking Checkov |

No existing hybrid landing zone was found in the subscription. The unrelated existing AKS POC is outside this change and will not be imported or modified. If applying this configuration to an existing deployment later, private AKS, registry zone redundancy, VM sizes or encryption changes can replace/cycle resources; only the actual saved plan can establish the precise impact.

## Cost review

Prepare a quote in the [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/) for one environment in West Europe plus a registry replica in North Europe. The previous Basic/Free/Standard design estimate is obsolete. Review these recurring charges explicitly:

- Premium Firewall uptime and data processing; VpnGw1 uptime and traffic.
- AKS Standard management tier, four D4ds_v5 nodes, and temporary node-pool rotation/surge capacity.
- Premium ACR in two regions, image storage and replication traffic.
- Private endpoints, DNS, peering traffic, public gateway/firewall IPs and logs.
- Private runner compute/storage and the chosen secure management access path.
- Security-owned Key Vault, key operations and DES dependencies.
- Microsoft Defender for Containers at subscription scope, potentially affecting other existing workloads.

Do not enable subscription-wide paid Defender automatically from each environment root. Its owner must review the existing setting, pricing and registry/private-cluster support once. The AKS sensor configuration and Checkov's registry-SKU check do not prove that Defender assessments are working. See [Defender vulnerability assessment](https://learn.microsoft.com/en-us/azure/defender-for-cloud/enable-vulnerability-assessment).

Review actual currency, subscription discounts, regional availability and quotas. Set an owner, budget and cleanup date before any apply. Stopping worker VMs does not stop Firewall, VPN or registry billing.

## Bootstrap dependencies

1. Select one environment and confirm the subscription, locations, budget and ownership.
2. Create or select the state backend. Use separate state keys and least-privilege Entra blob access; preserve versioning and recovery controls.
3. Have the security owner supply a healthy, same-region/same-subscription Disk Encryption Set and its customer-managed key. Confirm rotation, purge protection, key access and recovery. The AKS control-plane identity receives Reader on the DES; the DES identity's access to its key remains a security bootstrap responsibility. [AKS BYOK requirements](https://learn.microsoft.com/en-us/azure/aks/azure-disk-customer-managed-keys)
4. Supply at least one AKS administrator Entra group UUID. Configure GitHub's OIDC principals, protected deployment environments and variables listed in README.
5. Establish a private management runner before full deployment. For a greenfield network, review a separate network/bootstrap plan, create the approved runner access path, then prepare a fresh full plan. A runner in the shared subnet can reach the workload private endpoints on HTTPS. A runner in a separate management VNet additionally needs explicit peering, NSG allowances and links/forwarders for all three DNS zones. Do not assume peering alone provides DNS resolution. [AKS private DNS requirements](https://learn.microsoft.com/en-us/azure/aks/private-clusters)
6. Install reviewed versions of Azure CLI, Terraform, Helm, kubectl, kubelogin, Notation and Trivy on an ephemeral/dedicated runner. Install the approved Notation certificate and a single exact-repository trust rule at strict level, with explicit signer identities and no verification overrides. Never register untrusted fork jobs on this runner.
7. Establish the separate image-publisher/security workflow. Quarantine prevents ordinary pull access until a security identity releases the image and its signature artifacts. The deployment identity has AcrPull, not AcrQuarantineWriter or signing rights. Verify that unreleased images fail to pull. See the [ACR quarantine flow](https://github.com/Azure/acr/blob/main/docs/preview/quarantine/readme.md).
8. Provision a licensed Linux x86_64 Cisco lab with a reachable public IPv4 and UDP 500/4500 forwarding. No such lab exists for this user today. Do not use synthetic test IPs as a real peer. Supply the real VPN PSK through a secret store, never in Git or chat.

A region other than West Europe also requires reviewing the replica region, SKU availability, DNS naming, quotas and Cisco address-plan assumptions. The DES and ephemeral OS disks serve different encryption cases: **ephemeral OS disks are platform-key encrypted**; the DES applies where managed-disk CMK support exists. Do not claim CMK encryption of ephemeral OS storage.

## Remaining security gate

The scanner still reports CKV_AZURE_164 once for each registry. It demands legacy Docker Content Trust. Microsoft prevents enabling DCT on new registries after 31 May 2026 and recommends Notary Project migration. [Microsoft DCT guidance](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-content-trust)

No exemption has been added. The proposed deployment gate validates exact-repository strict Notation policy, explicit signer identity, digest format, signature verification and a blocking vulnerability scan. It still requires a real certificate/signing/release process and live negative tests. Admission-time signature verification in AKS must also be selected and validated before a production rollout; a CI gate alone cannot constrain other privileged deployment identities.

Before any exception or production claim, demonstrate an unsigned/untrusted image rejected, a signature from the wrong identity rejected, an unreleased image denied, a vulnerable image blocked and an approved image admitted. Only then can a reviewer decide whether a narrowly scoped legacy-policy exception correctly recognizes the replacement control. The current security job remains red by design; a successful mock plan is not a security approval.

## Actual plan and approval sequence

1. Supply real values for `onprem_public_ip`, `vpn_shared_key`, `disk_encryption_set_id` and `aks_admin_group_object_ids`, plus backend settings. Ensure no test fixture values are reused.
2. From the private operator/runner, initialize the chosen backend and create a saved plan using the README commands. Review its resource list, replacements, RBAC scopes, network paths, estimated cost and any tenant/subscription effects.
3. Keep binary plans private; do not upload them to the public repository. The workflow retains its artifact for one day. Summarize the non-sensitive changes for the user.
4. Obtain review of that concrete plan and the unresolved security gate. Do not apply this design, merge the paid review branch or enable paid subscription services solely because local tests pass.
5. After the actual plan and security controls are approved, apply the exact saved plan through the protected environment. A new code change or expired plan requires a fresh plan/review.

The manual workflow defaults `apply` to false and requires `main` plus security success before applying. Network/bootstrap and subscription-security changes need their own reviewed plans; they are not implicitly included in a plan for the application root.

## Acceptance evidence after deployment

- Private DNS: AKS API, ACR login/data endpoints and Key Vault resolve privately from the runner and AKS network; public data access is rejected.
- Identity: local AKS accounts disabled; the kubelet pulls only released images; workload identity reads only the required Key Vault secret; the app never returns its value.
- Scheduling: application replicas run on the user pool; critical-addon taints isolate system nodes.
- Security: IDPS and threat blocking active; managed disk/DES and host-encryption settings match the approved plan; Defender reports assessments; signature/quarantine/vulnerability negative tests fail as intended.
- AKS: rollout succeeds; `/healthz` and `/readyz` return 200 with the actual CSI mount; removing access or the required secret blocks readiness.
- Hybrid: both IKEv2/IPsec SAs are established, BGP peers established, expected routes learned, no bypass of firewall next hops, and on-premises LAN reaches the private test VM on TCP/8080.
- Operations: diagnostic logs arrive, drift detection works, budgets alert and a reviewed destroy plan covers all recurring stack resources.

Hybrid evidence remains blocked until a real lab is available. Azure-only tests must not be described as a verified Cisco integration.
