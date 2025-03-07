# Overview

# Redpanda AWS BYOVPC Terraform Module

This Terraform module provisions the necessary AWS infrastructure for a Redpanda customer-managed VPC cluster. It configures IAM roles, security groups, VPC components, and storage resources required for deploying Redpanda in a customer's AWS environment.

## Module Overview

This module deploys several core components:

1. **IAM Configuration**: Creates IAM roles, policies, and instance profiles for various Redpanda components
2. **Network Infrastructure**: Provisions VPC, subnets, route tables, and NAT gateways
3. **Security Groups**: Sets up security groups with appropriate ingress/egress rules
4. **Storage Resources**: Creates S3 buckets for cloud storage and management, and DynamoDB table for state locking

## Usage

```terraform
module "redpanda_byoc" {
  source = "redpanda-data/redpanda-byovpc/aws"

  region             = "us-east-1"
  aws_account_id     = "123456789012" # Optional if already authenticated
  common_prefix      = "redpanda"
  
  # VPC Configuration
  vpc_id              = "" # Leave empty to create a new VPC
  vpc_cidr_block      = "10.0.0.0/16"
  
  # Subnet Configuration
  private_subnet_cidrs = [
    "10.0.0.0/24",
    "10.0.2.0/24",
    "10.0.4.0/24"
  ]
  public_subnet_cidrs = []
  zones               = ["use1-az1", "use1-az2", "use1-az3"]
  
  # Tags and Conditions
  condition_tags      = {
    "redpanda-managed" = "true"
  }
  default_tags        = {
    "Environment" = "production"
  }
  ignore_tags         = ["AutoTag", "CreatedBy"]
  
  # Additional Configuration
  enable_private_link          = false
  create_rpk_user              = false
  force_destroy_cloud_storage  = false
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.8.5 |
| aws | Latest |

## Provider Configuration

This module requires the AWS provider to be configured:

```terraform
provider "aws" {
  region = var.region
  
  ignore_tags {
    keys = var.ignore_tags
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| region | The AWS region to deploy resources into | `string` | n/a | yes |
| aws_account_id | AWS account ID to use (if not already authenticated) | `string` | `""` | no |
| aws_access_key | AWS access key for the account | `string` | n/a | yes |
| aws_secret_key | AWS secret key for the account | `string` | n/a | yes |
| common_prefix | Prefix for naming resources | `string` | `"redpanda"` | no |
| vpc_id | Existing VPC ID (if not creating a new one) | `string` | `""` | no |
| vpc_cidr_block | CIDR block for the VPC (if creating a new one) | `string` | `"10.0.0.0/16"` | no |
| private_subnet_cidrs | CIDRs for private subnets | `list(string)` | See variables.tf | no |
| private_subnet_ids | IDs of existing private subnets | `list(string)` | `[]` | no |
| public_subnet_cidrs | CIDRs for public subnets | `list(string)` | `[]` | no |
| zones | AWS availability zone IDs | `list(string)` | See variables.tf | no |
| condition_tags | Tags used as conditions in IAM policies | `map(string)` | `{"redpanda-managed": "true"}` | no |
| default_tags | Tags to apply to all resources | `map(string)` | `{}` | no |
| ignore_tags | Tags to ignore during resource reconciliation | `list(string)` | `[]` | no |
| enable_private_link | Enable AWS PrivateLink support | `bool` | `false` | no |
| create_rpk_user | Create RPK user policies for testing | `bool` | `false` | no |
| force_destroy_cloud_storage | Force destroy the cloud storage bucket | `bool` | `false` | no |
| source_cluster_bucket_names | Bucket names of source clusters for read replicas | `set(string)` | `[]` | no |
| reader_cluster_id | ID of the reader cluster for read replicas | `string` | `""` | no |
| network_exclude_zone_ids | AZ IDs to exclude from selection | `list(string)` | `[]` | no |
| cloud_tags | Cloud-specific tags for resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| redpanda_agent_role_arn | ARN of the Redpanda Agent IAM role |
| agent_instance_profile_arn | ARN of the Redpanda Agent instance profile |
| connectors_node_group_instance_profile_arn | ARN of the Connectors node group instance profile |
| utility_node_group_instance_profile_arn | ARN of the Utility node group instance profile |
| redpanda_node_group_instance_profile_arn | ARN of the Redpanda node group instance profile |
| k8s_cluster_role_arn | ARN of the Kubernetes cluster IAM role |
| cloud_storage_bucket_arn | ARN of the Redpanda cloud storage S3 bucket |
| management_bucket_arn | ARN of the management S3 bucket |
| dynamodb_table_arn | ARN of the DynamoDB table for state locking |
| vpc_arn | ARN of the VPC |
| private_subnet_ids | JSON-encoded list of private subnet IDs |
| redpanda_agent_security_group_arn | ARN of the Redpanda Agent security group |
| connectors_security_group_arn | ARN of the Connectors security group |
| redpanda_node_group_security_group_arn | ARN of the Redpanda node group security group |
| utility_security_group_arn | ARN of the Utility security group |
| cluster_security_group_arn | ARN of the EKS cluster security group |
| node_security_group_arn | ARN of the EKS node shared security group |
| byovpc_rpk_user_policy_arns | JSON-encoded list of RPK user policy ARNs (if enabled) |
| permissions_boundary_policy_arn | ARN of the permissions boundary policy |
| private_subnet_arns | List of ARNs of the private subnets |

## Resources

### IAM Resources

The module creates IAM roles for various components:

- **Redpanda Agent**: Role for the agent VM that manages the Redpanda cluster
- **K8s Cluster**: Role for the EKS cluster
- **Redpanda Node Group**: Role for Redpanda broker nodes
- **Utility Node Group**: Role for utility nodes (load balancer controller, etc.)
- **Connectors Node Group**: Role for Redpanda connectors

### Networking Resources

- **VPC** (optional): Creates a new VPC if `vpc_id` is not provided
- **Subnets**: Private and public subnets in specified availability zones
- **NAT Gateway**: For private subnet internet access
- **Route Tables**: For public and private subnets
- **S3 Gateway Endpoint**: For efficient S3 access without NAT charges

### Security Groups

- **Redpanda Agent**: For the agent VM
- **Connectors**: For connector nodes
- **Redpanda Node Group**: For Redpanda broker nodes
- **Utility**: For utility nodes
- **Cluster**: For the EKS cluster
- **Node**: Shared security group for EKS nodes

### Storage Resources

- **Cloud Storage Bucket**: S3 bucket for Redpanda tiered storage
- **Management Bucket**: S3 bucket for Terraform state and configuration
- **DynamoDB Table**: For Terraform state locking

## Notes

1. Either `private_subnet_ids` or `private_subnet_cidrs` must be provided.
2. For Private Link support, set `enable_private_link = true`.
3. The tags specified in `condition_tags` must also be provided during cluster creation.
4. The module includes proper tag handling for all resources using `default_tags`.
5. For read replica clusters, configure `source_cluster_bucket_names` and `reader_cluster_id`.

## Examples

### Basic Usage with New VPC

```terraform
module "redpanda_byoc" {
  source = "redpanda-data/redpanda-byovpc/aws"
  
  region             = "us-west-2"
  common_prefix      = "redpanda-prod"
  
  vpc_cidr_block      = "10.0.0.0/16"
  private_subnet_cidrs = [
    "10.0.0.0/24",
    "10.0.2.0/24",
    "10.0.4.0/24"
  ]
  
  zones = ["usw2-az1", "usw2-az2", "usw2-az3"]
  
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

  region             = "us-east-1"
  common_prefix      = "redpanda-dev"
  
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

  region             = "us-east-2"
  common_prefix      = "redpanda-staging"
  
  vpc_cidr_block      = "10.0.0.0/16"
  private_subnet_cidrs = [
    "10.0.0.0/24",
    "10.0.2.0/24",
    "10.0.4.0/24"
  ]
  
  zones = ["use2-az1", "use2-az2", "use2-az3"]
  
  enable_private_link = true
  
  default_tags = {
    "Environment" = "staging"
    "Project"     = "redpanda"
    "Terraform"   = "true"
  }
}
```

## Ignore Tags

It can be useful to add ignore_tags to your workspace AWS provider declaration to avoid Terraform attempting to remove tags applied by external automation. More information is available here

https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/resource-tagging#ignoring-changes-in-all-resources

## Capture the output

The output of `terraform apply` should display a number of output values. For example:

```shell
agent_instance_profile_arn = "..."
byovpc_rpk_user_policy_arns = "[...]"
cloud_storage_bucket_arn = "..."
cluster_security_group_arn = "..."
connectors_node_group_instance_profile_arn = "..."
connectors_security_group_arn = "..."
dynamodb_table_arn = "..."
k8s_cluster_role_arn = "..."
management_bucket_arn = "..."
node_security_group_arn = "..."
permissions_boundary_policy_arn = "..."
private_subnet_ids = "[...]"
redpanda_agent_role_arn = "..."
redpanda_agent_security_group_arn = "..."
redpanda_node_group_instance_profile_arn = "..."
redpanda_node_group_security_group_arn = "..."
utility_node_group_instance_profile_arn = "..."
utility_security_group_arn = "..."
vpc_arn = "..."
```

These values can also be retrieved at any time by running `terraform output`.

Note these values. They are needed for the next steps. To continue with cluster creation, see
[Configure a Customer-Managed VPC on AWS](https://deploy-preview-12--rp-cloud.netlify.app/redpanda-cloud/get-started/cluster-types/byoc/vpc-byo-aws/). 
