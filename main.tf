data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
  depends_on = [ module.eks ]
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
  depends_on = [ module.eks ]
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.4.0"

  name                 = "vpc-${var.vpc_name}"
  cidr                 = "10.0.0.0/16"
  azs                  = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0"

  cluster_name    = "${var.cluster_name}"
  cluster_version = "1.28"
  cluster_endpoint_public_access = true
  
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  eks_managed_node_group_defaults = {
    instance_types = ["${var.cluster_instance_type}"]
    iam_role_additional_policies = {
      AmazonSSMReadOnlyAccess = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
      SecretsManagerReadWrite = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
      AmazonSQSFullAccess     = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
    }
  }

  eks_managed_node_groups = {
    one = {
      name = "ng-${var.cluster_name}-1"
      min_capacity     = 2
      max_capacity     = 3
      desired_capacity = 1
    }
    
  }
}

# Create EKS lb role
module "lb_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "eks-lb-role-${var.cluster_name}"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  depends_on = [module.eks]
}


# Use the AWS Load Balancer Controller Helm chart to deploy the controller
resource "helm_release" "aws_load_balancer_controller" { 
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = false
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.eks_lb_service_account.metadata[0].name
  }

  # set {
  #   name  = "serviceAccount.annotations.eks.amazonaws.com/role-arn"
  #   value = module.lb_role.iam_role_arn
  # }

  set {
    name = "image.repository"
    value = "602401143452.dkr.ecr.${var.aws_region}.amazonaws.com/amazon/aws-load-balancer-controller"
  }

  depends_on = [ kubernetes_service_account.eks_lb_service_account ]
}

# Create EKS Service Account
resource "kubernetes_service_account" "eks_lb_service_account" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn"               = module.lb_role.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
  depends_on = [ module.lb_role ]
}

# Create EKS pods Role
resource "aws_iam_role" "eks_pods_role" {
  name = "eks-pods-role-${var.cluster_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${module.eks.oidc_provider}"
        }
      }
    ]
  })
  depends_on = [ module.eks ]
}

# Create EKS pods Policy
resource "aws_iam_role_policy" "eks_pods_role_policy" {
  name = "eks-pods-role-policy-${var.cluster_name}"
  role = aws_iam_role.eks_pods_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "ssm:DescribeParameters",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "kms:DescribeCustomKeyStores",
          "kms:ListKeys",
          "kms:ListAliases",
          "kms:Decrypt",
          "kms:GetKeyRotationStatus",
          "kms:GetKeyPolicy",
          "kms:DescribeKey"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "sqs:DeleteMessage",
          "sqs:ReceiveMessage",
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ListQueues",
          "sqs:CreateQueue",
          "sqs:DeleteQueue"
        ]
        Effect   =  "Allow"
        Resource =  "*"
      }
    ]
  })

  depends_on = [ aws_iam_role.eks_pods_role ]
}

# Install the Secrets Store CSI Driver
resource "helm_release" "secret_store_driver" {
  name       = "csi-secrets-store"
  chart      = "secrets-store-csi-driver"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  depends_on = [ data.aws_eks_cluster_auth.cluster ]
  
  set {
    name  = "syncSecret.enabled"
    value = true
  }
  set {
    name  = "enableSecretRotation"
    value = true
  }
}

# Install the AWS Secrets Store CSI Driver Provider for AWS Secrets Manager
resource "helm_release" "secret_store_driver_provider_aws" {
  name       = "secrets-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  depends_on = [ helm_release.secret_store_driver ]
}


# Store cluster endpoint in SSM Parameter Store
resource "aws_ssm_parameter" "cluster_endpoint" {
  name        = "/${var.cluster_name}/${var.environment}/CLUSTER_ENDPOINT"
  description = "Tech challenge Kubernetes cluster endpoint"
  type        = "String"
  value       = module.eks.cluster_endpoint
  depends_on  = [module.eks]
}
