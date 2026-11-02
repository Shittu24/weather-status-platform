# Phase 4: short-lived AWS demonstration

Terraform owns AWS resources. Argo CD owns the app's ServiceAccount, ConfigMap, Deployment and Service. Bootstrap scripts own the CSI driver/provider, namespace, SecretProviderClass and Argo installation. The application is accessible through port forwarding; no ALB, public app route or DNS changes are included.

## Architecture and tradeoffs

- EKS 1.36 in us-east-1, in standard support when checked. API private access is enabled; public access is limited to the operator's current IPv4 /32. Access uses an explicit EKS access entry.
- Two private worker subnets in separate availability zones, two on-demand t3.medium nodes, encrypted 20 GiB gp3 disks, IMDSv2 required and hop limit 1. No node public IPs or SSH key.
- One public NAT gateway supports provider calls and registry/API access. This saves a second NAT gateway's cost but is not a highly available egress design. Cross-AZ NAT traffic can incur transfer charges. A free S3 gateway endpoint handles S3 traffic.
- EKS manages the cluster security group and node connectivity. The generated group is not a per-workload network policy. NetworkPolicy enforcement is a later exercise.
- The node role pulls ECR images; no expiring ECR Kubernetes Secret is needed. The CNI policy remains on the node role for this lab. Workload IMDS access is constrained, and Secrets Manager access is granted only to a separate Pod Identity role.
- EKS Pod Identity agent 1.4.1-eksbuild.3 and AWS secrets provider Helm chart 3.1.4 mount a demo value from Secrets Manager. Chart archive checksum is verified. Bootstrap explicitly enables serviceAccountTokenInSecrets because the EKS prerelease version suffix skipped the chart's version condition. The chart includes Secrets Store CSI Driver 1.6.1.
- The secret value is generated in memory and sent through boto3 over TLS. Terraform manages only the secret resource, never its value. No Kubernetes Secret copy is created. The CSI file uses mode 0444: readable by processes inside the container that mounts it, but not writable. The initial 0440 root-owned mount was unreadable to UID 10001; changing fsGroupPolicy did not fix the ephemeral mount, so that attempted change was reverted. Only authorized pods can obtain this CSI mount. It is a learning credential, not an Open-Meteo API key.
- Existing image findings remain documented in image-refresh.md. This is a restricted, temporary portfolio lab, not a production security approval.

## State and tool versions

Run `python scripts/install-cloud-tools.py` from the platform root to install the pinned Windows binaries. AWS CLI, kubectl and Python must already be installed.

Use the checksum-verified `tools/terraform.exe` 1.17.1, not the older system Terraform. AWS provider 6.71.0 is pinned, and provider lock files are committed. Helm is 4.3.1; Argo CD is 3.5.6.

The persistent `terraform/bootstrap` root owns the private encrypted/versioned S3 bucket and imports the existing ECR repository. Both have prevent_destroy safeguards. ECR expires untagged images after 14 days and retains tagged releases. ECR will not expire a manifest while it is referenced by a manifest list.

The disposable `terraform/envs/dev` root owns the VPC, EKS, workers, NAT, logs, IAM and demo secret. Both roots use different S3 keys with native lock files. Never destroy bootstrap as part of lab teardown. Back up and restrict state access; S3 versioning is recovery protection, not a substitute for least privilege.

For the very first bootstrap only, temporarily omit its backend block, initialize and plan/apply locally, then restore the block and run `init -migrate-state -backend-config=backend.hcl`. The initial import block adopts the existing ECR repository. The first bootstrap migration has already been performed in this account.

## Recreate and test

1. Authenticate with `aws login`. Create ignored `terraform/envs/dev/local.auto.tfvars` using the example. Use the current operator IPv4 /32 and a stable IAM principal ARN, not an STS session ARN.
2. From the platform root, initialize: `./tools/terraform.exe '-chdir=terraform/envs/dev' init '-backend-config=backend.hcl'`.
3. Create a saved plan: `./tools/terraform.exe '-chdir=terraform/envs/dev' plan '-out=../../../.local/dev.tfplan'`. Review with `terraform show`; check account, region, resource changes and cost before applying that exact plan.
4. Apply the reviewed plan: `./tools/terraform.exe '-chdir=terraform/envs/dev' apply '../../../.local/dev.tfplan'`.
5. Install the helper dependency in an isolated environment: `python -m venv .local/python`, then `./.local/python/Scripts/python.exe -m pip install -r scripts/requirements-aws.txt`.
6. Run `./scripts/bootstrap-aws.ps1`. It writes only `.local/aws-kubeconfig`, using context `weather-aws`, distinct from kind. A bootstrap rerun rotates the demo secret; restart app pods if needed to remount it.
7. Run `./scripts/sync-aws.ps1 -Revision (git rev-parse HEAD)` after the configuration is on main. Confirm Healthy/Synced and two Ready replicas.
8. Verify `/health`, `/ready`, `/version` and live selected-location weather through the Service. Verify the mounted file is readable without printing its contents. Try the same mount from an unassociated ServiceAccount and record the access failure.

Optional local access: `kubectl --kubeconfig .local/aws-kubeconfig --context weather-aws -n weather-dev port-forward service/weather 8002:80 --address 127.0.0.1`.

CI runs format and validation without AWS credentials. It cannot apply infrastructure. Local saved-plan application is the manual control point, and S3 locking prevents concurrent state changes. A GitHub environment-protected apply workflow has not been implemented; do not describe it as operational.

## Cost and teardown

Baseline estimate: EKS $0.10/hour, two Linux t3.medium workers about $0.0832/hour total, one NAT $0.045/hour, one public IPv4 $0.005/hour, plus 40 GiB gp3 (about $3.20/month prorated). Roughly $0.24/hour before NAT data, cross-AZ transfer, logs, Secrets Manager, ECR/S3 requests/storage, CPU credits and taxes. A four-hour demo baseline is about $1; this is not a spending cap. Creation/deletion time also counts. Check actual billing afterward.

Sources: [EKS pricing](https://aws.amazon.com/eks/pricing/), [VPC pricing](https://aws.amazon.com/vpc/pricing/), [EC2 T3 pricing](https://aws.amazon.com/ec2/instance-types/t3/), [EBS pricing](https://aws.amazon.com/ebs/pricing/).

Create and review the destroy plan, then apply it:

```powershell
./tools/terraform.exe '-chdir=terraform/envs/dev' plan -destroy '-out=../../../.local/dev-destroy.tfplan'
./tools/terraform.exe '-chdir=terraform/envs/dev' show '../../../.local/dev-destroy.tfplan'
./tools/terraform.exe '-chdir=terraform/envs/dev' apply '../../../.local/dev-destroy.tfplan'
./tools/terraform.exe '-chdir=terraform/envs/dev' state list
```

The disposable demo secret is intentionally deleted without recovery. No user data is stored in this lab. Check EKS cluster absence, terminated workers, NAT deletion and released EIP; an empty Terraform state alone is insufficient evidence. Retain bootstrap/ECR and the local kind cluster. Stop any AWS port-forward sessions. If interrupted during apply, inspect and resume cleanup—do not abandon billable resources.

References: [S3 backend locking](https://developer.hashicorp.com/terraform/language/backend/s3), [ASCP Pod Identity](https://docs.aws.amazon.com/secretsmanager/latest/userguide/ascp-pod-identity-integration.html).
