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
