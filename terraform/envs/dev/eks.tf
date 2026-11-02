resource "aws_iam_role" "cluster" {
  name               = "weather-dev-eks-cluster"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "eks.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${local.name}/cluster"
  retention_in_days = 7
}
resource "aws_eks_cluster" "main" {
  name                      = local.name
  role_arn                  = aws_iam_role.cluster.arn
  version                   = local.version
  enabled_cluster_log_types = ["api", "audit", "authenticator"]
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }
  upgrade_policy { support_type = "STANDARD" }
  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = [var.admin_cidr]
  }
  depends_on = [aws_iam_role_policy_attachment.cluster, aws_cloudwatch_log_group.eks]
}
resource "aws_eks_access_entry" "operator" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.admin_principal_arn
  type          = "STANDARD"
}
resource "aws_eks_access_policy_association" "operator" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.operator.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}
resource "aws_iam_role" "node" {
  name               = "weather-dev-eks-node"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy_attachment" "node" {
  for_each   = toset(["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryPullOnly", "AmazonEKS_CNI_Policy"])
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
}
resource "aws_launch_template" "node" {
  name_prefix = "weather-dev-"
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }
}
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "portfolio"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id
  version         = local.version
  ami_type        = "AL2023_x86_64_STANDARD"
  capacity_type   = "ON_DEMAND"
  instance_types  = ["t3.medium"]
  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 2
  }
  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }
  update_config { max_unavailable = 1 }
  depends_on = [aws_iam_role_policy_attachment.node, aws_route.nat]
}
resource "aws_eks_addon" "pod_identity" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "eks-pod-identity-agent"
  addon_version = "v1.4.1-eksbuild.3"
  depends_on    = [aws_eks_node_group.main]
}
output "cluster_name" { value = aws_eks_cluster.main.name }
output "node_role_arn" { value = aws_iam_role.node.arn }
