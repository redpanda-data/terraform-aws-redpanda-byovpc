resource "aws_route_table" "main" {
  count  = local.create_vpc ? 1 : 0
  vpc_id = data.aws_vpc.redpanda.id
  tags   = var.default_tags
}

moved {
  from = aws_route_table.main
  to   = aws_route_table.main[0]
}

resource "aws_route_table" "private" {
  count  = local.create_private_subnets ? length(var.private_subnet_cidrs) : 0
  vpc_id = data.aws_vpc.redpanda.id

  tags = merge(
    var.default_tags,
    {
      purpose = "private"
    }
  )
}

resource "aws_main_route_table_association" "vpc-main-route-table" {
  count          = local.create_vpc ? 1 : 0
  vpc_id         = data.aws_vpc.redpanda.id
  route_table_id = aws_route_table.main[0].id
}

moved {
  from = aws_main_route_table_association.vpc-main-route-table
  to   = aws_main_route_table_association.vpc-main-route-table[0]
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.main[0].id
}

resource "aws_route_table_association" "private" {
  count          = local.create_private_subnets ? length(var.private_subnet_cidrs) : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Routes S3 traffic to the local gateway endpoint
resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  count           = local.create_private_subnets && var.create_s3_gateway_endpoint ? length(var.private_subnet_cidrs) : 0
  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
  route_table_id  = aws_route_table.private[count.index].id
}

resource "aws_vpc_endpoint_route_table_association" "public_s3" {
  count           = local.create_vpc && length(var.public_subnet_cidrs) > 0 && var.create_s3_gateway_endpoint ? 1 : 0
  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
  route_table_id  = aws_route_table.main[0].id
}
