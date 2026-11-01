$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$k = @('--kubeconfig','.local/kubeconfig','--context','kind-weather-lab','-n','weather-dev')
Start-Transcript -Path evidence/secret-crash.txt -Force
try {
    $pods = kubectl @k get pods -l app=weather -o json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw 'Pod lookup failed' }
    $pod = $pods.items | Where-Object { $_.status.containerStatuses[0].ready -and -not $_.metadata.deletionTimestamp } | Select-Object -First 1
    if (-not $pod) { throw 'No ready pod' }
    $name = $pod.metadata.name
    $uid = $pod.metadata.uid
    $restarts = $pod.status.containerStatuses[0].restartCount
    Write-Output "Target pod: $name; initial restarts: $restarts"
    kubectl @k exec $name -- python -c "from pathlib import Path; p=Path('/var/run/secrets/weather-demo/demo_token'); assert p.read_text().startswith('demo-only-'); print('Demo Secret readable; value not displayed')"
    if ($LASTEXITCODE -ne 0) { throw 'Secret mount verification failed' }
    kubectl @k exec $name -- python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/health').status)"
    if ($LASTEXITCODE -ne 0) { throw 'Pre-crash request failed' }
    Write-Output 'Sending SIGKILL through the local kind container runtime; exit 137 is expected.'
    $containerId = $pod.status.containerStatuses[0].containerID -replace '^containerd://',''
    if ($pod.spec.nodeName -ne 'weather-lab-control-plane') { throw 'Unexpected node; refusing runtime kill' }
    docker exec weather-lab-control-plane ctr --namespace k8s.io tasks kill --signal SIGKILL $containerId
    if ($LASTEXITCODE -ne 0) { throw 'Runtime kill failed' }
    $recovered = $false
    for ($attempt = 0; $attempt -lt 45; $attempt++) {
        Start-Sleep -Seconds 2
        $current = kubectl @k get pod $name -o json | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) { throw 'Pod disappeared instead of restarting' }
        $status = $current.status.containerStatuses[0]
        if ($status.restartCount -gt $restarts -and $status.ready) { $recovered = $true; break }
    }
    if (-not $recovered) { throw 'Container did not recover within 90 seconds' }
    if ($current.metadata.uid -ne $uid) { throw 'Pod identity changed' }
    Write-Output "Same pod recovered; restart count: $($status.restartCount)"
    $status.lastState.terminated | Select-Object reason,exitCode,startedAt,finishedAt | Format-List
    if ($status.lastState.terminated.exitCode -ne 137) { throw 'Unexpected termination exit code' }
    kubectl @k logs $name -c weather --previous --tail=8
    if ($LASTEXITCODE -ne 0) { throw 'Previous logs unavailable' }
    kubectl @k exec $name -- python -c "import urllib.request; print(urllib.request.urlopen('http://weather/health', timeout=3).status)"
    if ($LASTEXITCODE -ne 0) { throw 'Post-recovery Service check failed' }
    kubectl @k get pods
} finally { Stop-Transcript }
