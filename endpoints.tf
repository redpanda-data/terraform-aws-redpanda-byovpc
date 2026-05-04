locals {
  # Interface endpoints are only needed when egress goes through TGW — they
  # bypass the TGW entirely for AWS service traffic, reducing cost and latency.
  interface_endpoints = local.use_tgw ? {
    "ecr-api" = "ecr.api"
    "ecr-dkr" = "ecr.dkr"
    "sts"     = "sts"
    "logs"    = "logs"
  } : {}
}

# Allows HTTPS from within the VPC to reach interface endpoint ENIs.
resource "aws_security_group" "vpc_endpoints" {
  count       = local.use_tgw ? 1 : 0
  name_prefix = "${var.common_prefix}-vpc-endpoints-"
  vpc_id      = data.aws_vpc.redpanda.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.redpanda.cidr_block]
  }

  tags = merge(var.default_tags, { Name = "${var.common_prefix}-vpc-endpoints" })
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = local.interface_endpoints
  vpc_id              = data.aws_vpc.redpanda.id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = local.tgw_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]

  tags = merge(var.default_tags, { Name = "${var.common_prefix}-${each.key}" })
}
