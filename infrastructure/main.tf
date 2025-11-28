# Networking - AWS VPC with public and private subnets
resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.environment}-${var.associated_project}-vpc"
  }
}

resource "aws_default_route_table" "default_rtb" {
  default_route_table_id = aws_vpc.main.default_route_table_id
  tags = {
    Name = "${var.environment}-default-rtb"
  }
}

# Network Module
module "subnet" {
  source          = "./modules/network"
  vpc_id          = aws_vpc.main.id
  vpc_cidr        = aws_vpc.main.cidr_block
  region          = var.region
  subnet_az       = var.az
  env             = var.environment
  vpc_endpoint_sg = aws_security_group.vpc_endpoints_sg.id
}

# Computing - AWS ECS
locals {
  cells = ["cell1", "cell2", "cell3"]

  cell_private_subnet_map = {
    cell1 = 0
    cell2 = 2
    cell3 = 4
  }
  cell_private_subnet_workround_map = {
    cell1 = 4
    cell2 = 0
    cell3 = 2
  }
  cell_public_subnet_map = {
    cell1 = 0
    cell2 = 1
    cell3 = 2
  }
}

module "computes" {
  source                     = "./modules/computes"
  for_each                   = toset(local.cells)
  cluster_name               = "cluster-${var.environment}-${each.key}"
  env                        = var.environment
  vpc_id                     = aws_vpc.main.id
  cell_name                  = each.key
  cluster_region             = var.region
  private_subnets            = [module.subnet.private_subnets[local.cell_private_subnet_map[each.key]]]
  private_subnets_workaround = [module.subnet.private_subnets[local.cell_private_subnet_workround_map[each.key]]]
}

module "eks_addons" {
  source          = "./modules/eks-addons"
  for_each        = toset(local.cells)
  cluster_name    = "cluster-${var.environment}-${each.key}"
  cluster_region  = var.region
  vpc_id          = aws_vpc.main.id
  min_node_count  = var.min_node_count
  max_node_count  = var.max_node_count
  node_group_name = module.computes[each.key].node_group_name
  depends_on      = [module.computes]
}

# Security - AWS SG

# Security - AWS SG for VPC Endpoints
resource "aws_security_group" "vpc_endpoints_sg" {
  name_prefix = "${var.environment}-vpc-endpoints"
  description = "Associated to ECR/s3 VPC Endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow Nodes to pull images from ECR via VPC endpoints"
    protocol        = "tcp"
    from_port       = 443
    to_port         = 443
    security_groups = [aws_security_group.ecs_sg.id]
  }
  ingress {
    protocol    = "tcp"
    from_port   = var.container_port
    to_port     = var.container_port
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_sg" {
  name_prefix = "${var.environment}-ecs-sg"
  description = "Associated to ECS"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol        = "tcp"
    from_port       = var.container_port
    to_port         = var.container_port
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    protocol        = "tcp"
    from_port       = 443
    to_port         = 443
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.environment}-alb-sg"
  description = "Associated to alb"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    protocol    = "tcp"
    from_port   = var.container_port
    to_port     = var.container_port
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "vpc_1_security_group" {
  vpc_id = aws_vpc.main.id
  # Add RDS Postgres ingress rule
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDS_SG"
  }
}
