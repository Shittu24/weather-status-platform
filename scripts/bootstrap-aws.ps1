$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
function Check-Native { if ($LASTEXITCODE -ne 0) { throw 'Previous command failed; bootstrap stopped.' } }
$k = @('--kubeconfig','.local/aws-kubeconfig','--context','weather-aws')
aws eks update-kubeconfig --name weather-dev --region us-east-1 --alias weather-aws --kubeconfig .local/aws-kubeconfig
Check-Native
kubectl @k get nodes
Check-Native
@'
apiVersion: v1
kind: Namespace
metadata:
  name: weather-dev
  labels:
    pod-security.kubernetes.io/enforce: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
'@ | kubectl @k apply -f -
Check-Native
./tools/helm.exe repo add aws-secrets-manager https://aws.github.io/secrets-store-csi-driver-provider-aws
Check-Native
./tools/helm.exe pull aws-secrets-manager/secrets-store-csi-driver-provider-aws --version 3.1.4 --destination .local
Check-Native
$chart = '.local/secrets-store-csi-driver-provider-aws-3.1.4.tgz'
if ((Get-FileHash $chart -Algorithm SHA256).Hash -ne '09321996A1F4902301F105C8A71913CFB2108C9397256FE8705AFBC6FFEDEE29') { throw 'CSI chart checksum changed' }
./tools/helm.exe upgrade --install secrets-provider $chart --namespace kube-system --kubeconfig .local/aws-kubeconfig --kube-context weather-aws --wait --timeout 5m
Check-Native
$secretArn = ./tools/terraform.exe '-chdir=terraform/envs/dev' output -raw demo_secret_arn
Check-Native
# Secret values are generated in helper memory and sent over TLS, never Terraform.
./.local/python/Scripts/python.exe scripts/populate-demo-secret.py
Check-Native
$spc = @{
    apiVersion='secrets-store.csi.x-k8s.io/v1'; kind='SecretProviderClass'
    metadata=@{name='weather-demo';namespace='weather-dev'}
    spec=@{provider='aws';parameters=@{
        region='us-east-1';usePodIdentity='true'
        objects="- objectName: `"$secretArn`"`n  objectType: secretsmanager`n  objectAlias: demo_token`n  filePermission: `"0440`""
    }}
}
$spc | ConvertTo-Json -Depth 8 | kubectl @k apply -f -
Check-Native
Invoke-WebRequest 'https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.6/manifests/install.yaml' -OutFile .local/argocd-install.yaml
kubectl @k -n argocd apply --server-side --force-conflicts -f .local/argocd-install.yaml
Check-Native
kubectl @k -n argocd rollout status deployment/argocd-server --timeout=300s
Check-Native
kubectl @k apply -f argocd/aws/project.yaml -f argocd/aws/application.yaml
Check-Native
Write-Host 'AWS platform bootstrapped. Merge GitOps configuration, then run sync-aws.ps1 with its commit SHA.'
