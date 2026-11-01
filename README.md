# Weather Status platform: local Kubernetes

Phase 2 runs the existing app in a single-node kind cluster on Docker Desktop. Two replicas demonstrate pod replacement, not node-level high availability. No AWS resources are used.

## Start or redeploy

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

The app image is loaded directly into kind and uses `imagePullPolicy: Never`. This is a local lab convenience; a missing image produces `ErrImageNeverPull`, not `ImagePullBackOff`. ECR/digest releases come later. Weather caches are per pod. Provider availability is intentionally independent of readiness.

Port forwarding selects a pod; if that pod is deleted, restart the port-forward command. It does not prove Service load balancing. An internal HTTP check through the Service is required for that path.

## Teardown

Stop port forwarding with Ctrl+C. To remove only this lab cluster:

```powershell
./tools/kind.exe delete cluster --name weather-lab
```

This removes the lab's Kubernetes resources; source files and Docker images remain. No real provider credentials are needed. The bootstrap script creates a random demo-only Secret directly through stdin, outside Git. The Deployment mounts it read-only at /var/run/secrets/weather-demo/demo_token (0440, group 10001). It is not an Open-Meteo API key and the app does not use it for authentication. Kubernetes Secret encoding is not encryption; this lab does not demonstrate encrypted storage.

## Secret and crash exercise

Run `./scripts/crash-drill.ps1` to check the mounted demo value without displaying it, force a container crash using the local kind runtime, inspect restart count and previous logs, and verify Service recovery. This retains the same pod UID. Evidence is in `evidence/secret-crash.txt`. The script is restricted to the weather-lab context and node.
