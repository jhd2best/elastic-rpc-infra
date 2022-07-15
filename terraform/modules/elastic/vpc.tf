data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  zones = slice(data.aws_availability_zones.available.names, 0, min(3, length(data.aws_availability_zones.available.names)))
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.${var.vpc_index}.0.0/16"
  tags = {
    Name = "${var.env}-${local.project}"
  }
}

resource "aws_subnet" "public" {
  count                   = length(local.zones)
  cidr_block              = "10.${var.vpc_index}.${count.index * 16}.0/20"
  availability_zone       = local.zones[count.index]
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.env}-${local.project}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.env}-${local.project}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.env}-${local.project}"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(local.zones)
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}

resource "aws_route" "igw" {
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.igw.id
  destination_cidr_block = "0.0.0.0/0"
}
