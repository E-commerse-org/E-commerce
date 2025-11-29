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

