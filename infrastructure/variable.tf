variable "region" {
  description = "The Region that I will implement my Infra in AWS"
  default     = "us-east-1"
}

variable "environment" {
  description = "The environment for the resources"
  type        = string
  default     = "dev"
}

variable "associated_project" {
  description = "The Project that infrastructure hosts"
  type        = string
  default     = "project"
}

variable "cidr_block" {
  description = "The CIDR block for the Network"
  type        = string
}

variable "az" {
  description = "The Availability Zones for the Subnets"
  type        = list(string)
}

variable "image_name" {
  description = "Contains the image name"
  type        = string
}

variable "container_port" {}
variable "cpu" {}
variable "memory" {}

variable "db_master_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
}
variable "repo_name" {}

# # DocumentDB Variables
# variable "docdb_master_username" {
#   description = "Master username for DocumentDB"
#   type        = string
#   sensitive   = true
# }

# variable "docdb_master_password" {
#   description = "Master password for DocumentDB"
#   type        = string
#   sensitive   = true
# }

# variable "docdb_instance_class" {
#   description = "Instance class for DocumentDB"
#   type        = string
#   default     = "db.t3.medium"
# }

# # ElastiCache Variables
# variable "redis_node_type" {
#   description = "Node type for ElastiCache Redis"
#   type        = string
#   default     = "cache.t3.micro"
# }
