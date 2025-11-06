output "public_subnets" {
  value = aws_subnet.public_subnet[*].id
}
output "private_subnets" {
  value = aws_subnet.private_subnet[*].id
}

output "vpc_endpoint_ecr_dkr_id" {
  description = "ID of ECR DKR VPC endpoint"
  value       = aws_vpc_endpoint.ecr_dkr.id
}

output "vpc_endpoint_ecr_api_id" {
  description = "ID of ECR API VPC endpoint"
  value       = aws_vpc_endpoint.ecr_api.id
}

output "vpc_endpoint_s3_id" {
  description = "ID of S3 Gateway endpoint"
  value       = aws_vpc_endpoint.s3_gateway.id
}

output "internet_gateway_id" {
  description = "ID of Internet Gateway"
  value       = aws_internet_gateway.igw.id
}
