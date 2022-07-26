# Name of the EKS cluster
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.id
}

# Version of the EKS cluster
output "cluster_version" {
  description = "Version of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.version
}

# The endpoint for your EKS Kubernetes API
output "cluster_endpoint" {
  description = "The endpoint for your EKS Kubernetes API"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

# AWS EKS IAM OIDC provider
output "iam_oidc_provider" {
  description = "AWS EKS IRSA id"
  value       = aws_iam_openid_connect_provider.aws_iam_openid_connect_provider
}

output "s3_persistence_role_arn" {
  value = aws_iam_role.persistence.arn
}