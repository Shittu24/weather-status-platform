# Local troubleshooting exercises

Run `./scripts/drills.ps1` from this directory. It deliberately changes only the weather-dev resources in kind-weather-lab and restores the checked-in manifests in a finally block. The transcript is saved in `evidence/drills.txt`. Do not use it against production.

| Exercise | Symptom | Diagnosis | Recovery |
|---|---|---|---|
| Delete a pod | Replica count temporarily decreases | Deployment/ReplicaSet creates a new pod with a new name | Wait for rollout; restart any port-forward tied to the deleted pod |
| Missing local image | New pod is 0/1 with ErrImageNeverPull | Events show the image is absent and pull policy is Never | Restore manifest image; confirm image was loaded into kind |
| Wrong Service target port | Internal HTTP request is refused although pods remain ready | Compare Service targetPort, EndpointSlice ports and container port | Reapply the manifest; verify internal HTTP 200 |
| Broken readiness route | Candidate pod runs but is not ready; rollout stalls | Probe events show HTTP 404; EndpointSlice ready=false for candidate | Restore `/ready`, wait for rollout and inspect endpoints |

Use the dedicated context on every command:

```powershell
kubectl --kubeconfig .local/kubeconfig --context kind-weather-lab -n weather-dev get pods
kubectl --kubeconfig .local/kubeconfig --context kind-weather-lab -n weather-dev describe deployment weather
kubectl --kubeconfig .local/kubeconfig --context kind-weather-lab -n weather-dev logs deployment/weather --tail=20
kubectl --kubeconfig .local/kubeconfig --context kind-weather-lab -n weather-dev get events --sort-by=.lastTimestamp
kubectl --kubeconfig .local/kubeconfig --context kind-weather-lab -n weather-dev get endpointslices
```

`logs --previous` is useful after a container restart in the same pod. Deleting a pod is different: its replacement has another identity. These exercises do not measure continuous availability or prove recovery from losing a node.

Open-Meteo is keyless. A separate demo-only Secret is mounted for learning and verified without printing its value. Run `./scripts/crash-drill.ps1` for the Secret and crash exercises. The runtime sends SIGKILL to the selected app container; Kubernetes restarts it in the same pod. Exit 137 here is from the deliberate kill, not proof of OOM: inspect the termination reason and events. `logs --previous` retrieves output from the terminated container.
