resource "aws_ssm_parameter" "name" {
  name  = "eks-cluster-name"
  type  = "String"
  value = "name-of-cluster-eks"
}

terraform {
  backend "s3" {
    bucket = "tech-challenge-61"
    key    = "infra-eks-tech-challenge"
    region = "us-east-1"
  }
}

