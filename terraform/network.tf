# Public Subnet (For Load Balancers / Public ingress)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false # Hardening: Prevent auto-assigning public IPs

  tags = {
    Name = "production-public-subnet-1a"
  }
}

# Isolated Private Subnet (Where our secure container will actually run)
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "production-private-subnet-1a"
  }
}

# Internet Gateway for public routing
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "production-igw"
  }
}

# Elastic IP for NAT Gateway Allocation
resource "aws_eip" "nat" {
  domain = "vpc"
  
  tags = {
    Name = "nat-gateway-eip"
  }
}

# NAT Gateway allowing private resources safe outbound traffic without public exposure
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "production-nat-gateway"
  }
  
  depends_on = [aws_internet_gateway.gw]
}

# Routing tables ensuring absolute traffic isolation
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-secure-route-table"
  }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}