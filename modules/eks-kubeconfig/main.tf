module "eks-kubeconfig" {
  source     = "hyperbadger/eks-kubeconfig/aws"
  version    = "1.0.0"
  cluster_id =  var.eks_cluster_id
}

resource "local_file" "kubeconfig" {
  content  = module.eks-kubeconfig.kubeconfig
  filename = "kubeconfig_${var.cluster_name}"
}
