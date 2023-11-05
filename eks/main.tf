resource "aws_ssm_parameter" "name" {
  name  = "eks-cluster-name"
  type  = "String"
  value = "name-of-cluster-eks"
}

terraform {
  backend "s3" {
    bucket = "tech-challenge-61/infra-eks-tech-challenge/"
    key    = "eks.tfstate"
    region = "us-east-1"
  }
}

