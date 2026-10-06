# AZs are looked up from the region the provider is configured for, so
# changing the region can never leave us pointing at AZs that don't exist.
data "aws_availability_zones" "available" {
  # checkov:skip=CKV_AWS_394:Only the first az_count zones are used (slice below), so a newly added AZ never changes the selection.
  state = "available"

  # Regular AZs only - never Local Zones / Wavelength Zones, even if the
  # account is opted in to them.
  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # One /24 per AZ, keyed by AZ name. Public: 10.20.0.0/24, 10.20.1.0/24 ...
  # Private starts at offset 10: 10.20.10.0/24, 10.20.11.0/24 ...
  public_subnets  = { for i, az in local.azs : az => cidrsubnet(var.vpc_cidr, 8, i) }
  private_subnets = { for i, az in local.azs : az => cidrsubnet(var.vpc_cidr, 8, i + 10) }
}

# ---------------------------------------------------------------------------
# VPC + Internet Gateway
# ---------------------------------------------------------------------------

resource "aws_vpc" "this" {
  # checkov:skip=CKV2_AWS_11:Flow logs bill for CloudWatch/S3 storage; out of scope for a cost-capped lab.
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.name}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-igw" }
}

# ---------------------------------------------------------------------------
# Public subnets (EC2, ALB)
# ---------------------------------------------------------------------------

resource "aws_subnet" "public" {
  # checkov:skip=CKV_AWS_130:Public subnets by design - the instance needs a public IP because there is no (paid) NAT Gateway.
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-public-${each.key}"
    Tier = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${var.name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Private subnets (RDS)
# ---------------------------------------------------------------------------

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name}-private-${each.key}"
    Tier = "private"
  }
}

# Optional NAT Gateway (single, in the first AZ) - off by default for cost.
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = { Name = "${var.name}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[local.azs[0]].id

  tags = { Name = "${var.name}-nat" }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[0].id
    }
  }

  tags = { Name = "${var.name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}


# ---------------------------------------------------------------------------
# Every VPC comes with a "default" security group that allows all traffic
# between its members. Nothing here uses it, so take it over and strip all
# its rules - anything accidentally launched with it gets no access at all.
# ---------------------------------------------------------------------------

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-default-sg-unused" }
}
