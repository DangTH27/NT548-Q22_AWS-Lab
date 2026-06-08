# ==============================================================
# VPC Module - Toàn bộ hạ tầng mạng
#
# Tài nguyên tạo ra:
#   - 1 VPC
#   - 2 Public Subnets  (AZ-a, AZ-b) → cho ALB, NAT Gateway
#   - 2 Private Subnets (AZ-a, AZ-b) → cho EC2 Web Servers
#   - 1 Internet Gateway
#   - 1 NAT Gateway + 1 Elastic IP
#   - Route Tables & Associations
# ==============================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ----------------------------------------------------------------
# VPC
# ----------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # Bật DNS để EC2 có hostname và resolve được tên miền AWS
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

# ----------------------------------------------------------------
# Internet Gateway - Cổng ra Internet cho Public Subnets
# ----------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

# ----------------------------------------------------------------
# Public Subnets
# count.index lặp qua từng CIDR, gán vào AZ tương ứng
# ----------------------------------------------------------------
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # EC2 trong Public Subnet sẽ được gán Public IP tự động
  # (ALB không cần điều này nhưng là best practice cho public tier)
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-subnet-${count.index + 1}"
    Tier = "public"
    AZ   = var.availability_zones[count.index]
  }
}

# ----------------------------------------------------------------
# Private Subnets - EC2 không có Public IP, chỉ ra ngoài qua NAT
# ----------------------------------------------------------------
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${local.name_prefix}-private-subnet-${count.index + 1}"
    Tier = "private"
    AZ   = var.availability_zones[count.index]
  }
}

# ----------------------------------------------------------------
# Elastic IP cho NAT Gateway
# depends_on IGW vì EIP allocation cần IGW hoạt động trước
# ----------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

# ----------------------------------------------------------------
# NAT Gateway
# Đặt ở Public Subnet đầu tiên (AZ-a)
#
# Luồng traffic của EC2 (Private Subnet):
#   EC2 → NAT GW → IGW → Internet
# Chiều ngược lại (từ Internet → EC2) bị block hoàn toàn
# ----------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${local.name_prefix}-nat-gw"
  }

  depends_on = [aws_internet_gateway.main]
}

# ----------------------------------------------------------------
# Route Table: Public Subnets → Internet qua IGW
# ----------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ----------------------------------------------------------------
# Route Table: Private Subnets → Internet qua NAT Gateway
# ----------------------------------------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
