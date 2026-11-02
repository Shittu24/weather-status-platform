# Phase 4 execution evidence

AWS creation began November 1, 2026 (US Eastern); application and access verification ran November 2 after resuming an interrupted session. The cluster remained running during the interruption and incurred charges. This was not an uninterrupted four-hour demo.

## Infrastructure

- [Platform PR 6](https://github.com/Shittu24/weather-status-platform/pull/6) introduced the Terraform roots, AWS GitOps deployment, bootstrap scripts and runbook.
- [Terraform CI](https://github.com/Shittu24/weather-status-platform/actions/runs/41375101587) passed format, provider initialization with committed locks, and validation for both roots without AWS credentials.
- Bootstrap imported the existing ECR repository, created six resources, and updated repository tags without replacing images. Both roots migrated/configured separate native-locking S3 backends.
- Verified bucket versioning Enabled, all four public-access blocks true, and an active `dev/terraform.tfstate.tflock` encrypted with AES256 during apply.
- Reviewed dev plan: 34 creates, no updates/deletes. Apply completed with 34 resources added. EKS control plane creation took about 11 minutes; nodes about 2 minutes.
- EKS 1.36, node Kubernetes version `v1.36.5-eks-6e7947a`, AL2023 release `1.36.5-20261031`. Two workers in private subnets across two AZs had no public IPs and required IMDSv2. Node-group health issues were empty.
- API public access was limited to the operator /32; private API access was enabled. One NAT gateway and an S3 gateway endpoint supplied outbound access. No public application load balancer was created.
- Before teardown, Terraform plan reported **No changes**.

## Application and workload identity

- Installed Pod Identity agent `v1.4.1-eksbuild.3`, AWS CSI provider chart 3.1.4 with Secrets Store CSI Driver 1.6.1, and Argo CD 3.5.6.
- Argo `weather-aws` synced platform revision `4fa1ae425c14eb70658807f72e8dc3a60f45d71c`, reporting Healthy/Synced. Two app replicas were Ready.
- Service `/health` and `/ready` returned HTTP 200; `/version` returned app commit `d84dfe985bfdfca8ff711c3240c40ad358d14411` in openmeteo mode. Weather for selected location 2337639 returned Ilorin, Kwara State, NG.
- Generated a random demo-only value in process memory and wrote it directly to Secrets Manager. Terraform never received its value. The role grants GetSecretValue/DescribeSecret only on that resource.
- Both UID 10001 application containers read the CSI-mounted demo value successfully; the verification printed only `secret readable; value withheld`.
- A pod using an unassociated ServiceAccount failed its mount with `ResourceNotFoundException`: **The token included in the request has no service account role association for it.** The test pod had no app Service selector label and was cleaned up afterward.

## Troubleshooting evidence

The initial file mode 0440 yielded root:root ownership, so the non-root app received PermissionError. Setting CSIDriver fsGroupPolicy to File did not change the observed behavior; that change was reverted. Using read-only mode 0444 allowed the authorized non-root container to read. File permissions do not replace IAM: the negative identity test still failed to mount the secret.

Bootstrap also explicitly opts the CSI driver into `serviceAccountTokenInSecrets`. The bundled chart's Kubernetes version condition did not enable it for the EKS version suffix, despite driver/API support. The corrected setting was verified with the successful remount.

## Scope and limitations

This demonstrates a private AWS lab, workload identity, GitOps deployment, Terraform state handling and teardown. It does not demonstrate public HTTPS ingress, production availability, a vulnerability-free image, or an automated environment-approved Terraform apply workflow. Applies are reviewed saved plans executed locally; CI cannot provision AWS. The seven high image findings remain tracked separately.
