resource "aws_route_table" "main" {
  vpc_id = data.aws_vpc.redpanda.id
  tags   = var.default_tags
}

locals {
  create_private_subnet_routes = local.create_private_subnets ? true : var.create_private_s3_route
}

resource "aws_route_table" "private" {
  count  = local.create_private_subnet_routes ? length(local.subnet_ids) : 0
  vpc_id = data.aws_vpc.redpanda.id

  tags = merge(
    var.default_tags,
    {
      purpose = "private"
    }
  )
}

resource "aws_main_route_table_association" "vpc-main-route-table" {
  vpc_id         = data.aws_vpc.redpanda.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "private" {
  count          = local.create_private_subnet_routes ? length(aws_route_table.private) : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Routes S3 traffic to the local gateway endpoint
resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  count           = length(aws_route_table.private)
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
  route_table_id  = aws_route_table.private[count.index].id
}

resource "aws_vpc_endpoint_route_table_association" "public_s3" {
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
  route_table_id  = aws_route_table.main.id
}
