module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "tech-challenge-vpc"
  cidr = "10.0.0.0/17"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# resource "aws_ssm_parameter" "name" {
#   name  = "eks-cluster-name"
#   type  = "String"
#   value = "name-of-cluster-eks"
# }

terraform {
  backend "s3" {
    bucket = "tech-challenge-61"
    key    = "infra-eks-tech-challenge/eks.tfstate"
    region = "us-east-1"
  }
}
