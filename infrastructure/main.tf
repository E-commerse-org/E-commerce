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
  cell_public_subnet_map = {
    cell1 = 0
    cell2 = 1
    cell3 = 2
  }
}
# ECR 
resource "aws_ecr_repository" "ecr_repo" {
  name = var.associated_project
}

module "computes" {
  source   = "./modules/computes"
  for_each = toset(local.cells)

  cluster_name            = "cluster-${var.environment}-${each.key}"
  env                     = var.environment
  vpc_id                  = aws_vpc.main.id
  repo_name               = aws_ecr_repository.ecr_repo.name
  image_name              = var.image_name
  cell_name               = each.key
  cluster_region          = var.region
  ecs_type                = "FARGATE"
  network_mode            = "awsvpc"
  memory_size             = var.memory
  cpu_size                = var.cpu
  desired_containers      = 3
  container_port          = var.container_port
  host_port               = var.container_port
  service_subnets         = [module.subnet.private_subnets[local.cell_private_subnet_map[each.key]]]
  service_security_groups = [aws_security_group.ecs_sg.id]
  public_ip               = false
  alb_subnets             = module.subnet.public_subnets[*]
  alb_security_groups     = [aws_security_group.ecs_sg.id, aws_security_group.alb_sg.id]
  alb_target_type         = "ip"
  db_name                 = aws_db_instance.rds_postgresql.db_name
  db_username             = aws_db_instance.rds_postgresql.username
  db_password             = aws_db_instance.rds_postgresql.password
  db_endpoint             = aws_db_instance.rds_postgresql.address
  db_port                 = aws_db_instance.rds_postgresql.port
  depends_on              = [aws_db_instance.rds_postgresql, aws_ecr_repository.ecr_repo]
}


resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.image_name}"
  retention_in_days = 7
}
# Database - AWS RDS

resource "aws_db_instance" "rds_postgresql" {
  db_name                     = "hello_db"
  identifier                  = "postgres-db"
  username                    = "hello_user"
  password                    = var.db_master_password
  allocated_storage           = 20
  storage_encrypted           = true
  engine                      = "postgres"
  engine_version              = "14"
  instance_class              = "db.t3.micro"
  apply_immediately           = true
  publicly_accessible         = false # default is false
  multi_az                    = false # using stand alone DB
  skip_final_snapshot         = true  # after deleting RDS aws will not create snapshot 
  copy_tags_to_snapshot       = true  # default = false
  db_subnet_group_name        = aws_db_subnet_group.db_attach_subnet.id
  vpc_security_group_ids      = [aws_security_group.ecs_sg.id, aws_security_group.vpc_1_security_group.id]
  auto_minor_version_upgrade  = false # default = false
  allow_major_version_upgrade = false # default = true
  backup_retention_period     = 0     # default value is 7
  delete_automated_backups    = true  # default = true

  tags = {
    Name = "${var.environment}-rds-posgress"
  }
}

resource "aws_db_subnet_group" "db_attach_subnet" {
  name = "db-subnet-group"
  subnet_ids = [
    "${module.subnet.private_subnets[1]}",
    "${module.subnet.private_subnets[3]}",
    "${module.subnet.private_subnets[5]}"
  ]
  tags = {
    Name = "${var.environment}-db-subnets"
  }
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


# # DocumentDB Clusters (One per Cell)
# resource "aws_docdb_subnet_group" "docdb_subnet_group" {
#   for_each = toset(local.cells)

#   name       = "${var.env}-${each.key}-docdb-subnet-group"
#   subnet_ids = [
#     var.private_subnet_ids[index(local.cells, each.key) * 2],
#     var.private_subnet_ids[index(local.cells, each.key) * 2 + 1]
#   ]

#   tags = {
#     Name = "${var.env}-${each.key}-docdb-subnet-group"
#     Cell = each.key
#   }
# }

# resource "aws_docdb_cluster" "documentdb" {
#   for_each = toset(local.cells)

#   cluster_identifier      = "${var.env}-${each.key}-docdb"
#   engine                  = "docdb"
#   master_username         = var.docdb_master_username
#   master_password         = var.docdb_master_password
#   db_subnet_group_name    = aws_docdb_subnet_group.docdb_subnet_group[each.key].name
#   vpc_security_group_ids  = [aws_security_group.docdb_sg[each.key].id]
#   skip_final_snapshot     = var.env == "dev" ? true : false
#   backup_retention_period = 7
#   preferred_backup_window = "07:00-09:00"

#   tags = {
#     Name        = "${var.env}-${each.key}-documentdb"
#     Cell        = each.key
#     Environment = var.env
#   }
# }

# resource "aws_docdb_cluster_instance" "docdb_instances" {
#   for_each = toset(local.cells)

#   identifier         = "${var.env}-${each.key}-docdb-instance"
#   cluster_identifier = aws_docdb_cluster.documentdb[each.key].id
#   instance_class     = var.docdb_instance_class

#   tags = {
#     Name = "${var.env}-${each.key}-docdb-instance"
#     Cell = each.key
#   }
# }

# # ElastiCache (Redis) Clusters (One per Cell)
# resource "aws_elasticache_subnet_group" "elasticache_subnet_group" {
#   for_each = toset(local.cells)

#   name       = "${var.env}-${each.key}-elasticache-subnet-group"
#   subnet_ids = [
#     var.private_subnet_ids[index(local.cells, each.key) * 2],
#     var.private_subnet_ids[index(local.cells, each.key) * 2 + 1]
#   ]

#   tags = {
#     Name = "${var.env}-${each.key}-elasticache-subnet-group"
#     Cell = each.key
#   }
# }

# resource "aws_elasticache_replication_group" "redis" {
#   for_each = toset(local.cells)

#   replication_group_id          = "${var.env}-${each.key}-redis"
#   replication_group_description = "Redis cluster for ${var.env} ${each.key}"
#   engine                        = "redis"
#   engine_version                = "7.0"
#   node_type                     = var.redis_node_type
#   num_cache_clusters            = 2
#   parameter_group_name          = "default.redis7"
#   port                          = 6379
#   subnet_group_name             = aws_elasticache_subnet_group.elasticache_subnet_group[each.key].name
#   security_group_ids            = [aws_security_group.elasticache_sg[each.key].id]
#   automatic_failover_enabled    = true
#   at_rest_encryption_enabled    = true
#   transit_encryption_enabled    = true

#   tags = {
#     Name        = "${var.env}-${each.key}-redis"
#     Cell        = each.key
#     Environment = var.env
#   }
# }

# Security Groups per Cell

# DocumentDB Security Groups
# resource "aws_security_group" "docdb_sg" {
#   for_each = toset(local.cells)

#   name_prefix = "${var.env}-${each.key}-docdb-sg"
#   description = "Security group for DocumentDB in ${each.key}"
#   vpc_id      = var.vpc_id

#   ingress {
#     description     = "MongoDB protocol from EKS nodes in same cell"
#     from_port       = 27017
#     to_port         = 27017
#     protocol        = "tcp"
#     security_groups = [module.eks_cells[each.key].node_security_group_id]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "${var.env}-${each.key}-docdb-sg"
#     Cell = each.key
#   }
# }

# # ElastiCache Security Groups
# resource "aws_security_group" "elasticache_sg" {
#   for_each = toset(local.cells)

#   name_prefix = "${var.env}-${each.key}-elasticache-sg"
#   description = "Security group for ElastiCache in ${each.key}"
#   vpc_id      = var.vpc_id

#   ingress {
#     description     = "Redis from EKS nodes in same cell"
#     from_port       = 6379
#     to_port         = 6379
#     protocol        = "tcp"
#     security_groups = [module.eks_cells[each.key].node_security_group_id]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "${var.env}-${each.key}-elasticache-sg"
#     Cell = each.key
#   }
# }
