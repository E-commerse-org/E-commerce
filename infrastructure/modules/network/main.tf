# Public Subnets Configuration
resource "aws_subnet" "public_subnet" {
  count                   = 3
  vpc_id                  = var.vpc_id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = var.subnet_az[count.index]
  tags = {
    Name = "${var.env}-public-subnet-${count.index}"
    "kubernetes.io/cluster/cluster-${var.env}-cell1" = "owned"
    "kubernetes.io/cluster/cluster-${var.env}-cell2" = "owned"
    "kubernetes.io/cluster/cluster-${var.env}-cell3" = "owned"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

# Private Subnet Configuration
resource "aws_subnet" "private_subnet" {
  count               = 6
  vpc_id              = var.vpc_id
  cidr_block          = cidrsubnet(var.vpc_cidr, 4, count.index + 3)
  availability_zone   = var.subnet_az[floor(count.index / 2)]

  tags = {
    Name = "${var.env}-private-subnet-${count.index}"
    "kubernetes.io/cluster/cluster-${var.env}-cell1" = "owned"
    "kubernetes.io/cluster/cluster-${var.env}-cell2" = "owned"
    "kubernetes.io/cluster/cluster-${var.env}-cell3" = "owned"
  }
  depends_on = [aws_vpc_endpoint.s3_gateway]
}

# Endpoints Configuration
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [
    aws_subnet.private_subnet[0].id,
    aws_subnet.private_subnet[2].id,
    aws_subnet.private_subnet[4].id
  ]
  private_dns_enabled = true
  security_group_ids = [aws_security_group.vpc_endpoints_sg.id]
  tags = {
    Name = "${var.env}-ecr-endpoint-data-plane"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [
    aws_subnet.private_subnet[0].id,
    aws_subnet.private_subnet[2].id,
    aws_subnet.private_subnet[4].id
  ]
  private_dns_enabled = true
  security_group_ids = [aws_security_group.vpc_endpoints_sg.id]

  tags = {
    Name = "${var.env}-ecr-endpoint-control-plane"
  }
}

resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [aws_route_table.private_rtb[0].id,aws_route_table.private_rtb[1].id,aws_route_table.private_rtb[2].id]

  tags = {
    "Name" = "${var.env}-s3-gateway"
  }
}

# Security - AWS SG for VPC Endpoints
resource "aws_security_group" "vpc_endpoints_sg" {
  name_prefix = "${var.env}-vpc-endpoints"
  description = "Associated to ECR/s3 VPC Endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow Nodes to pull images from ECR via VPC endpoints"
    protocol        = "tcp"
    from_port       = 443
    to_port         = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Public Route Table Configuration
resource "aws_route_table" "public_rtb" {
  vpc_id       = var.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.env}-public-rtb"
  }
}

resource "aws_route_table_association" "public_subnet_assoc" {
  count          = 3
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rtb.id
}



# Private Subnet Route table Configuration
resource "aws_route_table" "private_rtb" {
  count = 3
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw[count.index].id
  }

  tags = {
    Name = "private-rtb-${count.index}"
  }
}
resource "aws_route_table_association" "private_assoc" {
  for_each = {
    for index, subnet in aws_subnet.private_subnet :
    index => subnet.id
  }

  subnet_id = each.value
  route_table_id = aws_route_table.private_rtb[floor(each.key / 2)].id
}

# Accessing our network Using IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = var.vpc_id
  tags = {
    Name = "${var.env}-igw"
  }
}
resource "aws_eip" "eip_for_natgw" {
  count                   = 3
  tags = {
    Name = "nat-eip-${count.index}"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  count                   = 3
  allocation_id = aws_eip.eip_for_natgw[count.index].id
  subnet_id     = aws_subnet.public_subnet[count.index].id

  tags = {
    Name = "${var.env}-nat-${count.index}"
  }
  depends_on = [aws_internet_gateway.igw]
}
