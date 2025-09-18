variable "region" {
  type        = string
  description = <<-HELP
  The region where the VPC lives. Required.
  HELP
}

variable "aws_account_id" {
  type        = string
  default     = ""
  description = <<-HELP
  The AWS account ID where the Redpanda cluster will live. If not set, the
  account ID of the underlying Terraform run STS identity will be used.
  HELP
}

variable "public_subnet_cidrs" {
  type        = list(string)
  default     = []
  description = <<-HELP
  One public subnet will be created per cidr in this list.
  HELP
}

variable "private_subnet_cidrs" {
  type = list(string)
  default = [
    "10.0.0.0/24",
    "10.0.2.0/24",
    "10.0.4.0/24",
    "10.0.6.0/24",
    "10.0.8.0/24",
    "10.0.10.0/24"
  ]
  description = <<-HELP
  One private subnet will be created per cidr in this list.
  HELP
}

variable "private_subnet_ids" {
  type        = list(string)
  default     = []
  description = <<-HELP
  List of private subnet ids if created externally to this terraform. One of private_subnet_cidrs or private_subnet_ids
  must be provided.
  HELP
}

variable "zones" {
  type = list(string)
  default = [
    "use2-az1",
    "use2-az2",
    "use2-az3"
  ]
  description = <<-HELP
  The Availability Zone IDs to assign to the subnets, will be round-robined for each public and private subnet cidr.
  HELP
}

variable "condition_tags" {
  type = map(string)
  default = {
    "redpanda-managed" : "true",
  }
  description = <<-HELP
  Map of tag key/value pairs that will be included as conditional constraints on IAM resources. The redpanda-managed:true
  is a tag that the Redpanda logic applies to all resources it creates during both bootstrap (byoc apply) and provisioning.
  It is also recommended that you include a unique cloud provider tag on your cluster during cluster creation and then
  also include that tag here, this will constrain these resources to be available only to those IAM policies used by
  that cluster. (Please keep in mind that if you choose this route you should not remove or modify the unique cloud
  provider tag on the cluster unless you first remove it here.)
  HELP
}

variable "default_tags" {
  type        = map(string)
  default     = {}
  description = <<-HELP
  Map of keys and values that will be applied as tags to all resources
  HELP
}

variable "ignore_tags" {
  type        = list(string)
  default     = []
  description = <<-HELP
  List of tag keys that will be ignored during reconciliation of this terraform
  HELP
}

variable "enable_private_link" {
  type        = bool
  default     = false
  description = <<-HELP
  When true grants additional permissions required by Private Link. https://docs.redpanda.com/current/deploy/deployment-option/cloud/aws-privatelink/
  HELP
}

variable "common_prefix" {
  type        = string
  default     = "redpanda"
  description = <<-HELP
  Text to be included at the start of the name prefix on any objects supporting name prefixes.
  HELP
}

variable "create_rpk_user" {
  type        = bool
  default     = false
  description = <<-HELP
  The rpk user is one that can be used to test the minimum necessary permissions. It is not suggested for
  production use. When true this policy will be created, when false it will be skipped.
  HELP
}

variable "create_internet_gateway" {
  type        = bool
  default     = false
  description = <<-HELP
  When true, an Internet Gateway and route to the Gateway is created for inbound communication from Redpanda 
  Control Plane. This can be provisioned and managed separately. 
  HELP
}

variable "vpc_id" {
  type        = string
  default     = ""
  description = <<-HELP
  If the VPC is created and managed outside of this terraform the ID of the VPC should be provided and then VPC
  creation will be skipped.
  HELP
}

variable "vpc_cidr_block" {
  type        = string
  default     = "10.0.0.0/16"
  description = <<-HELP
  If the VPC is created and managed by this terraform this will be the cidr block of that VPC.
  HELP
}

variable "force_destroy_cloud_storage" {
  type        = bool
  default     = false
  description = <<-HELP
  When true the cloud storage bucket will be destroyed when running terraform destroy, even if it has contents.
  Normally recommended to keep this set to false, but may be set to true during certain types of testing.
  HELP
}

variable "source_cluster_bucket_names" {
  type        = set(string)
  default     = []
  description = <<-HELP
  Set of bucket names associated with redpanda clusters for which this cluster may be a read replica. For more information see:
  https://docs.redpanda.com/redpanda-cloud/get-started/cluster-types/byoc/remote-read-replicas/
  HELP
}

variable "reader_cluster_id" {
  type        = string
  default     = ""
  description = <<-HELP
  ID of the redpanda cluster. Only required when source_cluster_bucket_arns is provided. For more information see:
  https://docs.redpanda.com/redpanda-cloud/get-started/cluster-types/byoc/remote-read-replicas/
  HELP
}

variable "network_exclude_zone_ids" {
  type        = list(string)
  default     = []
  description = <<-HELP
  A list of availability zone IDs to exclude from automatic AZ selection. Optional.
  Only used when network_multi_az is true.
  HELP
}

variable "enable_redpanda_connect" {
  type        = bool
  default     = true
  description = <<-HELP
  When true grants additional permissions required by Redpanda Connect.
  HELP
}
