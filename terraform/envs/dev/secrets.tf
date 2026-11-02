resource "aws_secretsmanager_secret" "demo" {
  name_prefix             = "weather-dev-demo-"
  description             = "Disposable portfolio secret, value populated outside Terraform."
  recovery_window_in_days = 0
}
resource "aws_iam_role" "weather" {
  name = "weather-dev-pod"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Allow", Principal = { Service = "pods.eks.amazonaws.com" },
    Action = ["sts:AssumeRole", "sts:TagSession"],
    Condition = { StringEquals = {
      "aws:RequestTag/kubernetes-namespace"       = "weather-dev",
      "aws:RequestTag/kubernetes-service-account" = "weather"
    } }
  }] })
}
resource "aws_iam_role_policy" "secret" {
  role = aws_iam_role.weather.name
  policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect   = "Allow", Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
    Resource = aws_secretsmanager_secret.demo.arn
  }] })
}
resource "aws_eks_pod_identity_association" "weather" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "weather-dev"
  service_account = "weather"
  role_arn        = aws_iam_role.weather.arn
  depends_on      = [aws_eks_addon.pod_identity]
}
output "demo_secret_arn" { value = aws_secretsmanager_secret.demo.arn }
output "workload_role_arn" { value = aws_iam_role.weather.arn }
