# ---------------------------------------------------------------
# VPC
# ---------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block                       = var.vpc_cidr
  instance_tenancy                 = "default"
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = false # no IPv6 CIDR range

  tags = {
    Name = var.vpc_name
  }
}

# ---------------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "MY-IGW"
  }
}

# ---------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------
resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name = each.key
  }
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name = each.key
  }
}

# ---------------------------------------------------------------
# MAIN route table (the VPC's default/main RT)
# Public subnets are NOT explicitly associated - they use the
# main route table implicitly.
# ---------------------------------------------------------------
resource "aws_default_route_table" "main" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "MAIN"
  }
}

# ---------------------------------------------------------------
# NAT Gateway (public, in public-1a) + Elastic IP
# ---------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "MY-NAT-EIP"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id     = aws_eip.nat.id
  subnet_id         = aws_subnet.public["public-1a"].id
  connectivity_type = "public"

  tags = {
    Name = "MY-NAT"
  }

  depends_on = [aws_internet_gateway.main]
}

# ---------------------------------------------------------------
# Private-RT (explicit associations with both private subnets)
# ---------------------------------------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Private-RT"
  }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
