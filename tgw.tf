locals {
  use_tgw = var.transit_gateway_id != ""

  # TGW requires exactly one subnet per AZ. Group all private subnets by AZ
  # and take the first from each group.
  tgw_subnet_ids = [
    for az, ids in {
      for s in data.aws_subnet.private : s.availability_zone_id => s.id...
    } : ids[0]
  ]
}

# Attach the spoke VPC to the Transit Gateway using the private subnets.
resource "aws_ec2_transit_gateway_vpc_attachment" "redpanda" {
  count              = local.use_tgw ? 1 : 0
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = data.aws_vpc.redpanda.id
  subnet_ids         = local.tgw_subnet_ids

  # Allow the TGW to propagate routes back into the spoke VPC.
  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = merge(var.default_tags, {
    Name = "${var.common_prefix}-tgw-attachment"
  })
}

# Default route in each private route table → TGW (replaces NAT Gateway route).
# Only applies when private subnets are managed by this module; if subnets are
# provided externally their route tables must be updated outside this module.
resource "aws_route" "tgw_default" {
  count                  = local.use_tgw && local.create_private_subnets ? length(var.private_subnet_cidrs) : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.redpanda]
}
