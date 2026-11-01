$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$namespace = '{"apiVersion":"v1","kind":"Namespace","metadata":{"name":"weather-dev","labels":{"pod-security.kubernetes.io/enforce":"restricted"}}}'
$namespace | kubectl --kubeconfig .local/kubeconfig --context kind-weather-lab apply -f -
if ($LASTEXITCODE -ne 0) { throw 'Namespace setup failed' }
$exists = kubectl --kubeconfig .local/kubeconfig --context kind-weather-lab -n weather-dev get secret weather-demo --ignore-not-found -o name
if ($LASTEXITCODE -ne 0) { throw 'Secret lookup failed' }
if (-not $exists) {
    # This is a random demo value, not an Open-Meteo credential. Never print it.
    $demoValue = 'demo-only-' + [guid]::NewGuid().ToString('N')
    $manifest = @{apiVersion='v1';kind='Secret';metadata=@{name='weather-demo';namespace='weather-dev'};type='Opaque';stringData=@{demo_token=$demoValue}} | ConvertTo-Json -Depth 5 -Compress
    $manifest | kubectl --kubeconfig .local/kubeconfig --context kind-weather-lab apply -f -
    if ($LASTEXITCODE -ne 0) { throw 'Demo Secret creation failed' }
    $demoValue = $null
    $manifest = $null
} else { Write-Output 'Existing demo Secret preserved.' }
