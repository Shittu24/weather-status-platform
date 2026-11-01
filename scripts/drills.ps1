$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
function K {
    & kubectl --kubeconfig .local/kubeconfig --context kind-weather-lab -n weather-dev @args
    if ($LASTEXITCODE -ne 0) { throw "kubectl failed: $LASTEXITCODE" }
}
function Restore-App {
    K apply -f kubernetes/local.yaml
    K rollout status deployment/weather --timeout=120s
}
New-Item -ItemType Directory -Force evidence | Out-Null
Start-Transcript -Path evidence/drills.txt -Force
try {
    Write-Output 'DRILL 1: delete one pod and observe replacement'
    $before = (K get pods -l app=weather -o json | ConvertFrom-Json).items
    K delete pod $before[0].metadata.name --wait=true
    K rollout status deployment/weather --timeout=120s
    K get pods -l app=weather -o wide
    Write-Output 'DRILL 2: invalid local image (ErrImageNeverPull expected)'
    K set image deployment/weather weather=weather-status:missing-lab-image
    Start-Sleep -Seconds 8
    K get pods -l app=weather
    K get events --field-selector reason=ErrImageNeverPull
    Restore-App
    Write-Output 'DRILL 3: wrong Service target port; ready pods do not imply a working Service'
    '{"spec":{"ports":[{"name":"http","port":80,"targetPort":9999}]}}' | Set-Content .local/service-patch.json
    K patch service weather --type=merge --patch-file .local/service-patch.json
    K get service weather -o wide
    & kubectl --kubeconfig .local/kubeconfig --context kind-weather-lab -n weather-dev exec deployment/weather -- python -c "import urllib.request; urllib.request.urlopen('http://weather/health', timeout=3)"
    if ($LASTEXITCODE -eq 0) { throw 'Expected wrong-port request to fail' }
    Write-Output 'Expected Service request failure observed'
    Restore-App
    & kubectl --kubeconfig .local/kubeconfig --context kind-weather-lab -n weather-dev exec deployment/weather -- python -c "import urllib.request; print(urllib.request.urlopen('http://weather/health', timeout=3).status)"
    Write-Output 'DRILL 4: readiness failure; candidate stays out of ready endpoints'
    '{"spec":{"template":{"spec":{"containers":[{"name":"weather","readinessProbe":{"httpGet":{"path":"/not-ready","port":"http"}}}]}}}}' | Set-Content .local/readiness-patch.json
    K patch deployment weather --type=strategic --patch-file .local/readiness-patch.json
    Start-Sleep -Seconds 12
    K get pods -l app=weather
    K get endpointslices -l kubernetes.io/service-name=weather -o yaml
    K get events --field-selector reason=Unhealthy
} finally {
    Restore-App
    K get 'pods,svc'
    Stop-Transcript
}
