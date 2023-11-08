### VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/17"

  tags = {
    Name = "tech-challenge-vpc"
  }
}
### INTERNET GW
resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "tech-challenge-igw"
  }
}

### SUBNETS
resource "aws_subnet" "eks_private_us_east_1a" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.0.0/19"
  availability_zone = "us-east-1a"

  tags = {
    "Name"                            = "tech-challenge-private-us-east-1a"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/demo"      = "owned"
  }
}

resource "aws_subnet" "eks_private_us_east_1b" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.32.0/19"
  availability_zone = "us-east-1b"

  tags = {
    "Name"                            = "tech-challenge-private-us-east-1b"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/demo"      = "owned"
  }
}

resource "aws_subnet" "eks_public_us_east_1a" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.64.0/19"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    "Name"                       = "tech-challenge-public-us-east-1a"
    "kubernetes.io/role/elb"     = "1"
    "kubernetes.io/cluster/demo" = "owned"
  }
}

resource "aws_subnet" "eks_public_us_east_1b" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.96.0/19"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    "Name"                       = "tech-challenge-public-us-east-1b"
    "kubernetes.io/role/elb"     = "1"
    "kubernetes.io/cluster/demo" = "owned"
  }
}

### ELASTIC IP
resource "aws_eip" "eks_nat_eip" {
  domain = "vpc"

  tags = {
    Name = "tech-challenge-eip"
  }
}

### NAT GW
resource "aws_nat_gateway" "eks_nat_gw" {
  allocation_id = aws_eip.eks_nat_eip.id
  subnet_id     = aws_subnet.eks_public_us_east_1a.id

  tags = {
    Name = "tech-challenge-nat"
  }

  depends_on = [aws_internet_gateway.eks_igw]
}

### ROUTE TABLE
resource "aws_route_table" "eks_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.eks_nat_gw.id
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }

  tags = {
    Name = "tech-challenge-rt"
  }
}

# resource "aws_route_table" "eks_public_rt" {
#   vpc_id = aws_vpc.eks_vpc.id

#   route = [
#     {
#       cidr_block                 = "0.0.0.0/0"
#       gateway_id                 = aws_internet_gateway.eks_igw.id
#       nat_gateway_id             = ""
#       carrier_gateway_id         = ""
#       destination_prefix_list_id = ""
#       egress_only_gateway_id     = ""
#       instance_id                = ""
#       ipv6_cidr_block            = ""
#       local_gateway_id           = ""
#       network_interface_id       = ""
#       transit_gateway_id         = ""
#       vpc_endpoint_id            = ""
#       vpc_peering_connection_id  = ""
#     },
#   ]

#   tags = {
#     Name = "tech-challenge-public-rt"
#   }
# }

resource "aws_route_table_association" "eks_private_us_east_1a" {
  subnet_id      = aws_subnet.eks_private_us_east_1a.id
  route_table_id = aws_route_table.eks_rt.id
}

resource "aws_route_table_association" "eks_private_us_east_1b" {
  subnet_id      = aws_subnet.eks_private_us_east_1b.id
  route_table_id = aws_route_table.eks_rt.id
}

resource "aws_route_table_association" "eks_public_us_east_1a" {
  subnet_id      = aws_subnet.eks_public_us_east_1a.id
  route_table_id = aws_route_table.eks_rt.id
}

resource "aws_route_table_association" "eks_public_us_east_1b" {
  subnet_id      = aws_subnet.eks_public_us_east_1b.id
  route_table_id = aws_route_table.eks_rt.id
}

### EKS CLUSTER
resource "aws_iam_role" "eks_role" {
  name = "eks-cluster-demo"

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

resource "aws_iam_role_policy_attachment" "eks_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_role.name
}

variable "cluster_name" {
  default     = "tech-challenge-cluster"
  type        = string
  description = "AWS EKS CLuster Name"
  nullable    = false
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.eks_private_us_east_1a.id,
      aws_subnet.eks_private_us_east_1b.id,
      aws_subnet.eks_public_us_east_1a.id,
      aws_subnet.eks_public_us_east_1b.id
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_AmazonEKSClusterPolicy]
}

### EKS NODE
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-group-role"

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

resource "aws_iam_role_policy_attachment" "eks_nodes_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_nodes_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_nodes_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "tech-challenge-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn

  subnet_ids = [
    aws_subnet.eks_private_us_east_1a.id,
    aws_subnet.eks_private_us_east_1b.id,
  ]

  capacity_type  = "ON_DEMAND"
  instance_types = ["t2.micro"]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "general"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_nodes_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_nodes_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks_nodes_AmazonEC2ContainerRegistryReadOnly,
  ]
}

### OIDC
data "tls_certificate" "eks_cluster_certificate" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_cluster_certificate.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

