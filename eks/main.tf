resource "aws_ssm_parameter" "name" {
  name = "eks-cluster-name"
  type = string
  value = "name-of-cluster-eks"  
}