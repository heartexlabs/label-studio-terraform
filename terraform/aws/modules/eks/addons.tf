locals {
  addon_versions = {
    "coredns"            = "v1.8.7-eksbuild.3"
    "kube-proxy"         = "v1.24.7-eksbuild.2"
    "vpc_cni"            = "v1.12.0-eksbuild.1"
    "aws_ebs_csi_driver" = "v1.13.0-eksbuild.1"
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.eks_cluster.name

  addon_name    = "coredns"
  addon_version = local.addon_versions["coredns"]

  resolve_conflicts = "OVERWRITE"
  depends_on        = [
    aws_eks_node_group.eks_node_group,
  ]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  addon_name    = "kube-proxy"
  addon_version = local.addon_versions["kube-proxy"]

  resolve_conflicts = "OVERWRITE"
  depends_on        = [
    aws_eks_node_group.eks_node_group,
  ]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.eks_cluster.name

  addon_name    = "vpc-cni"
  addon_version = local.addon_versions["vpc_cni"]

  service_account_role_arn = aws_iam_role.cni_irsa_role.arn
  resolve_conflicts        = "OVERWRITE"
  depends_on               = [
    aws_eks_node_group.eks_node_group,
  ]
}

resource "aws_iam_role" "cni_irsa_role" {
  name        = "${var.name}-eks-cni-plugin"
  description = "CNI plugin role for EKS cluster ${var.name}"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${aws_iam_openid_connect_provider.aws_iam_openid_connect_provider.arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${replace(aws_iam_openid_connect_provider.aws_iam_openid_connect_provider.url, "https://", "")}:sub": "system:serviceaccount:kube-system:aws-node"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cni_irsa_policy" {
  role       = aws_iam_role.cni_irsa_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = aws_eks_cluster.eks_cluster.name

  addon_name    = "aws-ebs-csi-driver"
  addon_version = local.addon_versions["aws_ebs_csi_driver"]

  service_account_role_arn = aws_iam_role.ebs_csi_irsa_role.arn
  resolve_conflicts        = "OVERWRITE"
  depends_on               = [
    aws_eks_node_group.eks_node_group,
  ]
}

resource "aws_iam_role" "ebs_csi_irsa_role" {
  name        = "${var.name}-eks-ebs-csi-plugin"
  description = "EBS CSI plugin role for EKS cluster ${var.name}"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${aws_iam_openid_connect_provider.aws_iam_openid_connect_provider.arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${replace(aws_iam_openid_connect_provider.aws_iam_openid_connect_provider.url, "https://", "")}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }
  ]
}
POLICY
}

data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "ebs_csi_irsa_policy" {
  role       = aws_iam_role.ebs_csi_irsa_role.name
  policy_arn = data.aws_iam_policy.ebs_csi_policy.arn
}

resource "aws_iam_role" "persistence" {
  name        = "${var.name}-s3-persistence"
  description = "s3 persistence role for EKS cluster ${var.name}"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${aws_iam_openid_connect_provider.aws_iam_openid_connect_provider.arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${replace(aws_iam_openid_connect_provider.aws_iam_openid_connect_provider.url, "https://", "")}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "persistence" {
  name        = "${var.name}-s3-persistence"
  description = "Permissions for s3 bucket ${var.name}"
  policy      = jsonencode({
    "Version"   = "2012-10-17"
    "Statement" = [
      {
        "Effect" = "Allow"
        "Action" = [
          "s3:ListBucket"
        ],
        "Resource" = [
          var.persistence_s3_bucket_arn
        ]
      },
      {
        "Effect" : "Allow"
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ],
        "Resource" : [
          "${var.persistence_s3_bucket_arn}/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ],
        "Resource" : [
          var.persistence_s3_kms_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "persistence" {
  role       = aws_iam_role.persistence.name
  policy_arn = aws_iam_policy.persistence.arn
}
