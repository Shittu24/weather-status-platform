# Phase 2 evidence - November 1, 2026

Verified environment: Docker Desktop 4.80.0, kind 0.33.0, Kubernetes node 1.37.0, kubectl 1.36.1. One local control-plane node runs two application replicas.

- Built and loaded weather-status:phase2-local; deployed Namespace, ConfigMap, Deployment and ClusterIP Service.
- Both replicas became ready under restricted pod security, with startup/readiness/liveness probes and CPU/memory limits.
- Internal request from a pod through `http://weather/health` returned HTTP 200.
- External smoke checks through localhost:8001 passed health, readiness, version and live weather.
- Deleting one pod produced a new ready replacement.
- Missing local image produced ErrImageNeverPull; restoring the manifest recovered the rollout.
- Wrong targetPort caused connection refusal despite ready pods; restoring the Service recovered HTTP 200.
- Invalid readiness route produced HTTP 404 probe events and a running, unready candidate with EndpointSlice ready=false. Healthy existing replicas remained ready. Restored manifests successfully.

See drills.txt for the executed transcript. No continuous availability, load-balancing distribution, node-level resilience or recovery-time target was measured. The development Secret and explicit crash/previous-log exercises were subsequently completed; see secret-crash.txt. No AWS resources were created.

## Remaining Phase 2 exercises completed

- Created a random demo-only Kubernetes Secret outside Git and mounted it read-only. Verified the non-root user could read it without displaying its value.
- In-container SIGKILL was ineffective due to PID-namespace init protection. The repeatable script now kills the selected task through the kind node runtime.
- Observed termination reason Error, exit code 137, increased restart count and the same pod UID. Retrieved previous container logs and verified HTTP 200 through the Service after recovery.
