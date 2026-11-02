# Weather Status platform: Kubernetes and GitOps

Phase 2 runs the existing app in a single-node kind cluster on Docker Desktop. Two replicas demonstrate pod replacement, not node-level high availability. Phase 3 adds GitHub Actions, AWS ECR and Argo CD. Phase 4 adds a disposable AWS EKS environment managed by Terraform; see [the AWS runbook](docs/phase4.md). The local kind cluster remains available independently.

Phase 3 delivery and rollback exercises are verified; see [execution evidence](evidence/phase3.md). The base image has been refreshed and rescanned: 0 critical and 7 high findings remain. See [scan review](evidence/image-refresh.md) before any Phase 4 deployment.

## Phase 3: release through Git

The app repository verifies lint, dependencies, tests and a Docker smoke test. Only a successful main-branch build can publish its tested image to ECR using short-lived GitHub OIDC credentials. App main requires the `verify` check, including for administrators. PR builds do not publish.

The platform repository records the immutable image digest in `gitops/local/resources.yaml`. Merge a deployment PR, then explicitly sync that Git revision with Argo CD:

```powershell
./scripts/refresh-ecr-secret.ps1
git pull --ff-only
./scripts/sync-local.ps1 -Revision (git rev-parse HEAD)
```

Argo CD manages the ConfigMap, Deployment and Service. Namespace and secrets are bootstrapped separately. Sync and pruning are not automatic. Use a Git revert PR and sync its merged revision to restore a prior release; do not use `kubectl rollout undo` for GitOps rollback.

Local ECR pull credentials expire after 12 hours. Run `aws login` and refresh the secret before pulling new images after expiration. Credentials pass through stdin and are never committed. This manual mechanism is for kind; EKS node IAM replaces it in Phase 4. The random mounted demo secret is not weather-provider authentication.

The ECR repository has immutable tags and scan-on-push enabled. The dependency audit blocks CI; ECR findings are a separate review, not currently a release gate. ECR storage may incur charges. No EKS cluster, EC2 instance or load balancer has been created for Phase 3.

For a fresh lab, run the Phase 2 bootstrap below, then `./scripts/install-argocd.ps1`, apply `argocd/project.yaml` and `argocd/application.yaml` with the explicit local kubeconfig/context, refresh the ECR secret, and sync main. Once Argo manages the app, use the GitOps path instead of the Phase 2 redeploy script. The Phase 2 fault drills mutate resources directly; they are historical exercises, not the normal release workflow.

## Phase 2 bootstrap (before enabling Argo CD)

From this directory in PowerShell, with Docker Desktop running:

```powershell
./scripts/deploy-local.ps1
kubectl --kubeconfig .local/kubeconfig --context kind-weather-lab -n weather-dev port-forward service/weather 8001:80 --address 127.0.0.1
```

Keep port forwarding running and open http://localhost:8001. The Compose app uses port 8000 separately. Test from another terminal:

```powershell
python ../weather-status-app/scripts/smoke.py http://127.0.0.1:8001
```

The script uses the downloaded, checksum-verified kind 0.33.0 binary in `tools/kind.exe` and kubectl supplied by Docker Desktop. A fresh machine needs these tools installed first: [kind installation](https://kind.sigs.k8s.io/docs/user/quick-start/). The node image is version-pinned to 1.37.0. Kubeconfig is stored only in ignored `.local/`; do not commit it or share its contents.

## What the manifests do

- Namespace: groups the lab and enforces restricted pod security.
- ConfigMap: selects live Open-Meteo mode. Restart the Deployment after changing environment configuration.
- Deployment: maintains two replicas and rolls updates with zero unavailable replicas allowed during rollout.
- Probes: startup waits for initialization; readiness controls Service eligibility; liveness detects an unresponsive process.
- Service: stable internal address and selector for ready app pods, with port 80 routed to container port 8000.
- Resources/security: CPU and memory requests/limits, UID 10001, read-only root filesystem, no service-account token, no added Linux capabilities.

The app image is loaded directly into kind and uses `imagePullPolicy: Never`. This is a local lab convenience; a missing image produces `ErrImageNeverPull`, not `ImagePullBackOff`. Phase 3 uses the separate GitOps manifest with an ECR digest and IfNotPresent instead. Weather caches are per pod. Provider availability is intentionally independent of readiness.

Port forwarding selects a pod; if that pod is deleted, restart the port-forward command. It does not prove Service load balancing. An internal HTTP check through the Service is required for that path.

## Teardown

Stop port forwarding with Ctrl+C. To remove only this lab cluster:

```powershell
./tools/kind.exe delete cluster --name weather-lab
```

This removes the lab's Kubernetes resources; source files and Docker images remain. No real provider credentials are needed. The bootstrap script creates a random demo-only Secret directly through stdin, outside Git. The Deployment mounts it read-only at /var/run/secrets/weather-demo/demo_token (0440, group 10001). It is not an Open-Meteo API key and the app does not use it for authentication. Kubernetes Secret encoding is not encryption; this lab does not demonstrate encrypted storage.

## Secret and crash exercise

Run `./scripts/crash-drill.ps1` to check the mounted demo value without displaying it, force a container crash using the local kind runtime, inspect restart count and previous logs, and verify Service recovery. This retains the same pod UID. Evidence is in `evidence/secret-crash.txt`. The script is restricted to the weather-lab context and node.
