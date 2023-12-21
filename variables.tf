variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type = string
  default = "tech-challenge-61"
}

variable "cluster_instance_type" {
  type    = string
  default = "t3.small"
}

variable "vpc_name" {
  type    = string
  default = "tech-challenge-61-eks"
}

variable "environment" {
  type    = string
  default = "dev"
}
