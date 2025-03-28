# Overview

# Redpanda AWS BYOVPC Terraform Module

This Terraform module provisions the necessary AWS infrastructure for a Redpanda BYOVPC cluster. It configures IAM 
roles, security groups, VPC components, and storage resources required for deploying Redpanda in a customer's AWS 
environment.

## Module Overview

This module deploys several core components:

1. **IAM Configuration**: Creates IAM roles, policies, and instance profiles for various Redpanda components
2. **Network Infrastructure**: Provisions VPC, subnets, route tables, and NAT gateways
3. **Security Groups**: Sets up security groups with appropriate ingress/egress rules
4. **Storage Resources**: Creates S3 buckets for cloud storage and management, and DynamoDB table for state locking

## Guidance

1. Either `private_subnet_ids` or `private_subnet_cidrs` must be provided.
2. For Private Link support, set `enable_private_link = true`.
3. The tags specified in `condition_tags` must also be provided during cluster creation.
4. The module includes proper tag handling for all resources using `default_tags`.
5. For read replica clusters, configure `source_cluster_bucket_names` and `reader_cluster_id`.
6. It can be useful to add ignore_tags to your workspace AWS provider declaration to avoid Terraform attempting to remove tags applied by external automation. More information is available here: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/resource-tagging#ignoring-changes-in-all-resources

## Examples

### Basic Usage where module will create the VPC

```terraform
module "redpanda_byoc" {
  source = "redpanda-data/redpanda-byovpc/aws"

  region = "us-east-2"
  zones  = [
    "use2-az1",
    "use2-az2",
    "use2-az3"
  ]

  common_prefix = "redpanda-prod"

  vpc_cidr_block       = "10.0.0.0/16"
  private_subnet_cidrs = [
    "10.0.0.0/24",
    "10.0.2.0/24",
    "10.0.4.0/24",
    "10.0.6.0/24",
    "10.0.8.0/24",
    "10.0.10.0/24"
  ]
  public_subnet_cidrs = [
    "10.0.1.0/24",
    "10.0.3.0/24",
    "10.0.5.0/24",
    "10.0.7.0/24",
    "10.0.9.0/24",
    "10.0.11.0/24"
  ]

  default_tags = {
    "Environment" = "production"
    "Project"     = "redpanda"
    "Terraform"   = "true"
  }
}
```

### Using Existing VPC and Subnets

```terraform
module "redpanda_byoc" {
  source = "redpanda-data/redpanda-byovpc/aws"

  region = "us-east-2"
  zones  = [
    "use2-az1",
    "use2-az2",
    "use2-az3"
  ]

  common_prefix = "redpanda-dev"

  vpc_id             = "vpc-1234567890abcdef0"
  private_subnet_ids = ["subnet-1234567890abcdef0", "subnet-0fedcba0987654321"]

  default_tags = {
    "Environment" = "development"
    "Project"     = "redpanda"
    "Terraform"   = "true"
  }
}
```

### With Private Link Enabled

```terraform
module "redpanda_byoc" {
  source = "redpanda-data/redpanda-byovpc/aws"

  region = "us-east-2"
  zones  = [
    "use2-az1",
    "use2-az2",
    "use2-az3"
  ]

  common_prefix = "redpanda-staging"

  vpc_cidr_block       = "10.0.0.0/16"
  private_subnet_cidrs = [
    "10.0.0.0/24",
    "10.0.2.0/24",
    "10.0.4.0/24"
  ]

  enable_private_link = true

  default_tags = {
    "Environment" = "staging"
    "Project"     = "redpanda"
    "Terraform"   = "true"
  }
}
```

