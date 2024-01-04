data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
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
  
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  eks_managed_node_group_defaults = {
    instance_types = ["${var.cluster_instance_type}"]
    iam_role_additional_policies = {
      AmazonSSMReadOnlyAccess = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
      SecretsManagerReadWrite = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
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

# Store cluster endpoint in SSM Parameter Store
resource "aws_ssm_parameter" "cluster_endpoint" {
  name        = "/${var.cluster_name}/${var.environment}/CLUSTER_ENDPOINT"
  description = "Tech challenge Kubernetes cluster endpoint"
  type        = "String"
  value       = module.eks.cluster_endpoint
  depends_on  = [module.eks]
}
