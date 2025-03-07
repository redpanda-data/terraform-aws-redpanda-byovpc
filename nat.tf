resource "aws_eip" "nat_gateway" {
  domain = "vpc"
  tags   = var.default_tags
}

resource "aws_internet_gateway" "redpanda" {
  count  = local.create_vpc ? 1 : 0
  vpc_id = data.aws_vpc.redpanda.id
  tags   = var.default_tags
}

resource "aws_nat_gateway" "redpanda" {
  count         = length(aws_subnet.public) > 0 ? 1 : 0
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.public[0].id
  depends_on = [
    aws_internet_gateway.redpanda,
  ]
  tags = var.default_tags
}

locals {
  create_private_routes = length(aws_subnet.public) > 0 && length(aws_subnet.private) > 0
}

resource "aws_route" "nat" {
  count                  = local.create_private_routes ? length(var.private_subnet_cidrs) : 0
  route_table_id         = aws_route_table.private.*.id[count.index]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.redpanda[0].id
}

resource "aws_route" "public" {
  count                  = local.create_vpc ? 1 : 0
  route_table_id         = aws_route_table.main.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.redpanda[0].id
}
