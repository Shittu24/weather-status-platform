$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
function Check-Exit { if ($LASTEXITCODE -ne 0) { throw "Command failed: $LASTEXITCODE" } }
if (Test-Path .local/kubeconfig) {
    $managed = kubectl --kubeconfig .local/kubeconfig --context kind-weather-lab -n argocd get applications.argoproj.io weather-local --ignore-not-found -o name 2>$null
    if ($managed) { throw 'Argo CD owns weather-local. Change gitops/local in Git and sync; do not run the Phase 2 deploy script.' }
}
$clusters = & ./tools/kind.exe get clusters
Check-Exit
if ($clusters -notcontains 'weather-lab') {
    New-Item -ItemType Directory -Force .local | Out-Null
    & ./tools/kind.exe create cluster --name weather-lab --config kind.yaml --kubeconfig .local/kubeconfig --image kindest/node:v1.37.0 --wait 120s
    Check-Exit
} else {
    & ./tools/kind.exe export kubeconfig --name weather-lab --kubeconfig .local/kubeconfig
    Check-Exit
}
docker build -t weather-status:phase2-local ../weather-status-app
Check-Exit
& ./tools/kind.exe load docker-image weather-status:phase2-local --name weather-lab
Check-Exit
& ./scripts/bootstrap-secret.ps1
kubectl --kubeconfig .local/kubeconfig --context kind-weather-lab apply -f kubernetes/local.yaml
Check-Exit
kubectl --kubeconfig .local/kubeconfig --context kind-weather-lab -n weather-dev rollout restart deployment/weather
Check-Exit
kubectl --kubeconfig .local/kubeconfig --context kind-weather-lab -n weather-dev rollout status deployment/weather --timeout=120s
Check-Exit
kubectl --kubeconfig .local/kubeconfig --context kind-weather-lab -n weather-dev get pods,svc
Check-Exit
