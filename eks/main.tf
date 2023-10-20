resource "aws_ssm_parameter" "name" {
  name  = "eks-cluster-name"
  type  = "String"
  value = "name-of-cluster-eks"
}