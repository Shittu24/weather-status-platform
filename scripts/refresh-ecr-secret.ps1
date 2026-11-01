$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$k = @('--kubeconfig','.local/kubeconfig','--context','kind-weather-lab')
$registry = '975049996360.dkr.ecr.us-east-1.amazonaws.com'
$token = aws ecr get-login-password --region us-east-1
if ($LASTEXITCODE -ne 0) { throw 'AWS login required before refreshing the pull secret' }
try {
    $auth = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("AWS:$token"))
    $config = @{auths = @{$registry = @{auth = $auth}}} | ConvertTo-Json -Depth 5 -Compress
    $secret = @{apiVersion='v1'; kind='Secret'; metadata=@{name='ecr-pull'; namespace='weather-dev'}; type='kubernetes.io/dockerconfigjson'; stringData=@{'.dockerconfigjson'=$config}}
    # Replace through stdin: neither command-line arguments nor files contain the token.
    $secret | ConvertTo-Json -Depth 8 -Compress | kubectl @k apply --server-side --field-manager=ecr-refresh -f -
    if ($LASTEXITCODE -ne 0) { throw 'Pull secret refresh failed' }
} finally {
    $token = $null; $auth = $null; $config = $null; $secret = $null
}
Write-Host 'Local ECR pull secret refreshed. Refresh again before pulling after 12 hours.'
