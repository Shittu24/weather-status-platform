param([Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{40}$')][string]$Revision)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$k = @('--kubeconfig','.local/aws-kubeconfig','--context','weather-aws')
$patch = @{operation=@{sync=@{revision=$Revision; prune=$false}}} | ConvertTo-Json -Depth 5
$patch | Set-Content .local/sync-aws.json -Encoding ascii
kubectl @k -n argocd patch application weather-aws --type merge --patch-file .local/sync-aws.json
if ($LASTEXITCODE -ne 0) { throw 'Could not request sync' }
for ($attempt=0; $attempt -lt 90; $attempt++) {
    $raw = kubectl @k -n argocd get application weather-aws -o json
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read Argo application' }
    $app = $raw | ConvertFrom-Json
    $op = $app.status.operationState
    if ($op.syncResult.revision -eq $Revision) {
        if ($op.phase -in @('Failed','Error')) { throw $op.message }
        if ($op.phase -eq 'Succeeded' -and $app.status.health.status -eq 'Healthy' -and $app.status.sync.revision -eq $Revision -and $app.status.sync.status -eq 'Synced') {
            Write-Host "Argo CD synced $Revision; application Healthy."
            exit 0
        }
    }
    Start-Sleep -Seconds 2
}
throw 'Sync did not become healthy within 180 seconds; inspect Argo application and pod events.'
