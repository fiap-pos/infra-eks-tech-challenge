resource "aws_eks_cluster" "tech_challenge_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.tech_challenge_cluster_role.arn

  vpc_config {
    subnet_ids              = var.aws_public_subnet
    endpoint_public_access  = var.endpoint_public_access
    endpoint_private_access = var.endpoint_private_access
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = [aws_security_group.tech_challenge_node_group_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.tech_challenge_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.tech_challenge_AmazonEKSVPCResourceController,
  ]
}

resource "aws_eks_node_group" "tech_challenge_node_group" {
  cluster_name    = aws_eks_cluster.tech_challenge_cluster.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.tech_challenge_node_group_role.arn
  subnet_ids      = var.aws_public_subnet
  instance_types  = var.instance_types

  remote_access {
    source_security_group_ids = [aws_security_group.tech_challenge_node_group_sg.id]
    ec2_ssh_key               = var.key_pair
  }

  scaling_config {
    desired_size = var.scaling_desired_size
    max_size     = var.scaling_max_size
    min_size     = var.scaling_min_size
  }

  depends_on = [
    aws_iam_role_policy_attachment.tech_challenge_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.tech_challenge_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.tech_challenge_AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "aws_security_group" "tech_challenge_node_group_sg" {
  name_prefix = "tech_challenge_node_group_sg"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "tech_challenge_cluster_role" {
  name = "tech_challenge_cluster_role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "tech_challenge_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.tech_challenge_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "tech_challenge_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.tech_challenge_cluster_role.name
}

resource "aws_iam_role" "tech_challenge_node_group_role" {
  name = "tech_challenge_node_group_role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "tech_challenge_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.tech_challenge_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "tech_challenge_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.tech_challenge_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "tech_challenge_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.tech_challenge_node_group_role.name
}
