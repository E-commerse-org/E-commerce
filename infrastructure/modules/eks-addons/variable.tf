# Horizontal Scaling Configuration
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
variable "cluster_name" {}
variable "cluster_region" {}
variable "vpc_id" {}
variable "node_group_name" {}
