$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$k = @('--kubeconfig','.local/kubeconfig','--context','kind-weather-lab')
New-Item -ItemType Directory -Force .local | Out-Null
$version = 'v3.5.6'
Invoke-WebRequest "https://raw.githubusercontent.com/argoproj/argo-cd/$version/manifests/install.yaml" -OutFile .local/argocd-install.yaml
'{"apiVersion":"v1","kind":"Namespace","metadata":{"name":"argocd"}}' | kubectl @k apply -f -
if ($LASTEXITCODE -ne 0) { throw 'Namespace creation failed' }
kubectl @k -n argocd apply --server-side --force-conflicts -f .local/argocd-install.yaml
if ($LASTEXITCODE -ne 0) { throw 'Argo CD installation failed' }
kubectl @k -n argocd rollout status deployment/argocd-server --timeout=180s
if ($LASTEXITCODE -ne 0) { throw 'Argo CD server is not ready' }
kubectl @k -n argocd get pods
