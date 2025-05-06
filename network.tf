locals {
  create_vpc = var.vpc_id == "" ? true : false

  # We start from the given set of explicitly selected zones and add random
  # zones to have at least min_zones AZs, no matter if multi-az or single-az.
  min_zones = 3

  zones = (
    length(var.zones) >= local.min_zones
    ? var.zones
    : concat(var.zones, slice(random_shuffle.az.result, 0, local.min_zones - length(var.zones)))
  )

  create_private_subnets = length(var.private_subnet_ids) == 0 && length(var.private_subnet_cidrs) > 0
}

data "aws_availability_zones" "available_additional_zones" {
  state = "available"

  # Don't include local zones since they require explicit opt-in by
  # customers.
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }

  # We exclude prohibited zones as well as zones explicitly selected
  exclude_zone_ids = concat(var.network_exclude_zone_ids, var.zones)
}

resource "random_shuffle" "az" {
  input = data.aws_availability_zones.available_additional_zones.zone_ids
}

resource "aws_vpc" "redpanda" {
  count                = local.create_vpc ? 1 : 0
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = var.default_tags
}

data "aws_vpc" "redpanda" {
  id = local.create_vpc ? aws_vpc.redpanda[0].id : var.vpc_id
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = data.aws_vpc.redpanda.id
  availability_zone_id    = element(local.zones, count.index)
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.default_tags,
    {
      # Hints k8s where it can provision public network load balancers.
      "kubernetes.io/role/elb" = 1,
      # We add this tag to enable discovering the subnet from Terraform code
      # that provisions Redpanda clusters, as another alternative.
      "redpanda.subnet.public" = 1
    }
  )
}

resource "aws_subnet" "private" {
  count                   = local.create_private_subnets ? length(var.private_subnet_cidrs) : 0
  vpc_id                  = data.aws_vpc.redpanda.id
  availability_zone_id    = element(local.zones, count.index)
  cidr_block              = var.private_subnet_cidrs[count.index]
  map_public_ip_on_launch = false

  tags = merge(
    var.default_tags,
    {
      # Hints k8s where it can provision private network load balancers.
      "kubernetes.io/role/internal-elb" = 1,
      # We add this tag to enable discovering the subnet from Terraform code
      # that provisions Redpanda clusters, as another alternative.
      "redpanda.subnet.private" = 1
    }
  )
}

locals {
  provided_subnet_ids = var.private_subnet_ids
  created_subnet_ids  = aws_subnet.private.*.id
  subnet_ids          = length(var.private_subnet_ids) > 0 ? local.provided_subnet_ids : local.created_subnet_ids
}

data "aws_subnet" "private" {
  count = length(local.subnet_ids)
  id    = local.subnet_ids[count.index]
}

data "aws_vpc_endpoint_service" "s3" {
  service      = "s3"
  service_type = "Gateway"
}

# Creates a private gateway vpc endpoint for S3 traffic. So traffic to S3
# doesn't go through the NAT gateway, which is more expensive.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.aws_vpc.redpanda.id
  service_name      = data.aws_vpc_endpoint_service.s3.service_name
  vpc_endpoint_type = data.aws_vpc_endpoint_service.s3.service_type
  tags              = var.default_tags
}

# This block has 2 purposes:
#
# 1. Ensures that the default security group created by the VPC is properly
#    tagged with the default provider tags.
# 2. Since the default security group is not used by any of the resources
#    managed by Redpanda, for security, we're denying all ingress and egress
#    traffic.
#
# ----------
# Important:
# ----------
# The `aws_default_security_group` resource behaves differently from normal
# resources. Terraform does not create this resource but instead attempts to
# "adopt" it into management. On adoption it immediately removes all ingress and
# egress rules in the security group and recreates it with the rules specified
# here. Check the docs for more details.
resource "aws_default_security_group" "redpanda" {
  count   = local.create_vpc ? 1 : 0
  vpc_id  = data.aws_vpc.redpanda.id
  ingress = []
  egress  = []
  tags    = var.default_tags
}
