variable "vpc_id" {}
variable "vpc_cidr" {}
variable "subnet_az" {
  type = list(string)
}
variable "env" {}
variable "region" {}

