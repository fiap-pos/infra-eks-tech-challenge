data "aws_availability_zones" "available" {}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

module "vpc" {
  source = "./modules/vpc"
  aws_region = var.aws_region
  cluster_name = var.cluster_name
  vpc_name = var.vpc_name
}

module "eks" {
  source = "./modules/eks"
  aws_region = var.aws_region
  cluster_name = var.cluster_name
  cluster_instance_type = var.cluster_instance_type
  vpc_private_subnets = module.vpc.private_subnets
  vpc_id = module.vpc.vpc_id
  depends_on = [ module.vpc.vpc_id, module.vpc.private_subnets ]
}

module "eks-kubeconfig" {
  source = "./modules/eks-kubeconfig"
  eks_cluster_id = module.eks.cluster_id
  cluster_name = var.cluster_name
  depends_on = [module.eks]
}
