region             = "us-east-1"
environment        = "dev"
associated_project = "myapp"
cidr_block         = "10.0.0.0/16"
az                 = ["us-east-1a", "us-east-1b", "us-east-1c"]
ecr_name           = "dev-myapp"

# EKS Configuration
eks_version         = "1.31"
node_instance_types = ["t3.medium"]
min_nodes           = 1
max_nodes           = 3
desired_nodes       = 2

# DocumentDB Configuration
docdb_master_username = "admin"
docdb_master_password = "YourSecurePassword123!" # Use AWS Secrets Manager in production
docdb_instance_class  = "db.t3.medium"

# Redis Configuration
redis_node_type = "cache.t3.micro"
