provider "aws" {
  region = "us-east-1"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "vwnunes-tech-challenge-61"
    key    = "infra-eks-tech-challenge/eks.tfstate"
    region = "us-east-1"
  }

  required_version = ">= 1.6.1"
}
