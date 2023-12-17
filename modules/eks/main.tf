module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.30.3"

  cluster_name    = "${var.cluster_name}"
  cluster_version = "1.24"
  subnet_ids      = var.vpc_private_subnets

  vpc_id = var.vpc_id

  eks_managed_node_groups = {
    first = {
      desired_capacity = 1
      max_capacity     = 2
      min_capacity     = 1
      instance_type = "${var.cluster_instance_type}"
    }
  }
}
