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
7. To enable Redpanda SQL, set `enable_redpanda_sql = true`. The module creates the cloud-storage S3 bucket (server-side encryption AES256, versioning Disabled, public access blocked) along with a dedicated node-group IAM instance profile and security group. Wire the module outputs `rpsql_node_group_instance_profile_arn`, `rpsql_security_group_arn`, and `rpsql_cloud_storage_bucket_arn` into the Redpanda cluster's customer-managed resources (`rpsql_node_group_instance_profile`, `rpsql_security_group`, and `rpsql_cloud_storage_bucket`).
8. Keep `create_eks_nodegroup_service_linked_role = true` (the default) unless you manage the EKS node group service-linked role yourself. See [EKS Node Group Service-Linked Role](#eks-node-group-service-linked-role) for details.
9. For a dual (public+private) listener cluster, set `enable_public_private_connections = true` and provide public subnets in every AZ that has a private subnet. See [Dual (public+private) listener clusters](#dual-publicprivate-listener-clusters) for details.

## EKS Node Group Service-Linked Role

EKS managed node groups require the `AWSServiceRoleForAmazonEKSNodegroup` service-linked role to exist in the AWS
account. This role is normally created automatically the first time an EKS node group is created in an account, but in
brand new (or tightly restricted) AWS accounts it may not exist yet. If it is missing, Redpanda cluster creation fails
when provisioning the EKS node groups with an IAM error such as:

```
Error creating node group: operation error EKS: CreateNodegroup ... GetRole ...
role AWSServiceRoleForAmazonEKSNodegroup ... cannot be found
```

To avoid this, the module ensures the role exists by running
`aws iam create-service-linked-role --aws-service-name eks-nodegroup.amazonaws.com` when
`create_eks_nodegroup_service_linked_role = true` (the default). This requires:

- The AWS CLI to be installed and on the `PATH` of the machine running `terraform apply` (the role is created via a
  `local-exec` provisioner).
- The credentials used by the AWS CLI to have the `iam:CreateServiceLinkedRole` permission.

If the role already exists in the account, the command is a no-op and the apply continues.

Set `create_eks_nodegroup_service_linked_role = false` only if you manage this role separately or cannot run the AWS
CLI from your Terraform environment. In that case, create the role manually before creating the Redpanda cluster:

```shell
aws iam create-service-linked-role --aws-service-name eks-nodegroup.amazonaws.com
```

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


## Dual (public+private) listener clusters

To host a **dual listener** cluster — one that serves both a public, internet-reachable Kafka API
tier and a private tier from the same brokers — set `enable_public_private_connections = true` and provide
public subnets in **every AZ that has a private (broker) subnet**, either as existing subnets via
`public_subnet_ids` or as CIDRs for the module to create via `public_subnet_cidrs`. Set only one of
the two; providing both fails the apply.

`public_subnet_cidrs` only applies when **this module creates the VPC**. If you bring your own VPC
via `vpc_id` — the BYOVPC case — the module does not create subnets, so supply existing ones via
`public_subnet_ids`; setting `public_subnet_cidrs` alongside `vpc_id` fails with a precondition.

Enabling this opens the Redpanda node security group's public-tier broker ports (`30042-30044`) to
`0.0.0.0/0`; the private tier's ports (`30092-30094`) and the Admin API stay restricted to private
ranges and are reached only through the internal seed load balancer.

If you provide existing public subnets via `public_subnet_ids`, each one must:

1. Have a route to an internet gateway.
2. Be tagged `"kubernetes.io/role/elb" = 1`.
3. Have `map_public_ip_on_launch` enabled — brokers there advertise per-broker node addresses, so
   without it the public tier advertises addresses that do not resolve. This one **is** validated.

Requirements 1 and 2 are **not** validated by the module: the cluster fails later rather than at
plan. Module-created subnets satisfy all three.

If any AZ with a private subnet has no corresponding public subnet, the **apply** fails with a
precondition error naming the missing AZ (mid-apply, not at plan, when the module is creating the
subnets: the check reads `data.aws_subnet.public`, whose values are unknown until they exist) (it does not silently degrade or place brokers in the
wrong AZ). Fix it by adding a public subnet — via `public_subnet_ids` or `public_subnet_cidrs` — in
that AZ.

The module exports `public_subnet_id_list` (subnet IDs) and `public_subnet_arns` (subnet ARNs) for
wiring into the Redpanda cluster's customer-managed resources.

This module only opens the ports and validates/exports the subnets; it is a prerequisite, not the
whole feature. A dual BYOVPC cluster also needs a corresponding change on the control-plane side
(per-AZ seed-subnet selection) before it can actually be created.

```terraform
module "redpanda_byoc" {
  source = "redpanda-data/redpanda-byovpc/aws"

  region = "us-east-2"
  zones  = [
    "use2-az1",
    "use2-az2",
    "use2-az3"
  ]

  common_prefix = "redpanda-dual"

  vpc_cidr_block       = "10.0.0.0/16"
  private_subnet_cidrs = [
    "10.0.0.0/24",
    "10.0.2.0/24",
    "10.0.4.0/24"
  ]
  public_subnet_cidrs = [
    "10.0.1.0/24",
    "10.0.3.0/24",
    "10.0.5.0/24"
  ]

  enable_public_private_connections = true

  default_tags = {
    "Environment" = "production"
    "Project"     = "redpanda"
    "Terraform"   = "true"
  }
}
```

## AWS Glue Iceberg catalog

To use AWS Glue Data Catalog as the Iceberg REST catalog
(`iceberg_catalog_type=rest` with endpoint
`https://glue.<region>.amazonaws.com/iceberg`, `aws_sigv4` authentication and
`iceberg_rest_catalog_credentials_source=sts`), set
`enable_glue_iceberg_catalog = true`. The module then:

1. Allows the required Glue catalog/database/table actions in the **agent
   permissions boundary**, scoped to this account and region — without this,
   the boundary caps every agent-created role and no attached policy can grant
   Glue access (denials read
   `... because no permissions boundary allows the glue:GetCatalog action`).
2. Creates a `glue-iceberg` IAM policy with the same scoping, exported as
   `glue_iceberg_policy_arn`.

The only Glue callers are two **agent-created IRSA roles** — Glue (like S3)
never goes through the node group instance profiles. Both roles exist only
after cluster creation, so the module cannot attach the policy to them itself.
Attach `glue_iceberg_policy_arn` to both from the workspace that creates the
`redpanda_cluster` (their names are deterministic):

```terraform
resource "aws_iam_role_policy_attachment" "glue_broker_irsa" {
  role       = "redpanda-cloud-storage-manager-${redpanda_cluster.this.id}"
  policy_arn = module.redpanda_byovpc.glue_iceberg_policy_arn
  depends_on = [redpanda_cluster.this]
}

resource "aws_iam_role_policy_attachment" "glue_rpsql_engine_irsa" {
  role       = "redpanda-${redpanda_cluster.this.id}-redpanda-oxla-cluster"
  policy_arn = module.redpanda_byovpc.glue_iceberg_policy_arn
  depends_on = [redpanda_cluster.this]
}
```

Without these, Iceberg translation fails its first catalog call
(`glue:GetCatalog`) and writes nothing — no data files, no DLQ — and the
Redpanda SQL engine's `REFRESH` of the Glue-backed catalog fails with
`Forbidden`.
