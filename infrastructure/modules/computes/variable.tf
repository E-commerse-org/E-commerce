# variable "repo_name" {}
# variable "image_name" {}
variable "cluster_name" {}
variable "cell_name" {}
variable "cluster_region" {}
variable "env" {}
variable "vpc_id" {}
# variable "db_name" {}
# variable "db_username" {}
# variable "db_password" {}
# variable "db_endpoint" {}
# variable "db_port" {}
variable "private_subnets" {}
variable "private_subnets_workaround" {}

# Kubernetes Version
variable "kubernetes_version" {
  description = "The Kubernetes version to use for the EKS cluster."
  type        = string
  default     = "1.29"
}
# Node Group Instance Type
variable "instance_type" {
  description = "The instance type for the EKS worker nodes."
  type        = string
  default     = "t3.micro"
}
# Horizontal Scaling Configuration
variable "min_node_count" {
  description = "The minimum number of worker nodes for the node group (for HA and cost control)."
  type        = number
  default     = 1 # Minimum 2 nodes across 3 AZs for high availability
}
variable "desired_node_count" {
  description = "The desired number of worker nodes to start with."
  type        = number
  default     = 1
}
variable "max_node_count" {
  description = "The maximum number of worker nodes to scale out to."
  type        = number
  default     = 3 # Allows for significant horizontal scaling
}

