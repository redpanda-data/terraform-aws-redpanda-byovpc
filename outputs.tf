output "redpanda_agent_role_arn" {
  value = aws_iam_role.redpanda_agent.arn
}

output "connectors_node_group_instance_profile_arn" {
  value = aws_iam_instance_profile.connectors_node_group.arn
}

output "redpanda_connect_node_group_instance_profile_arn" {
  value = var.enable_redpanda_connect ? aws_iam_instance_profile.redpanda_connect_node_group[0].arn : null
}

output "rpsql_node_group_instance_profile_arn" {
  value = var.enable_redpanda_sql ? aws_iam_instance_profile.rpsql_node_group[0].arn : null
}

output "utility_node_group_instance_profile_arn" {
  value = aws_iam_instance_profile.utility.arn
}

output "redpanda_node_group_instance_profile_arn" {
  value = aws_iam_instance_profile.redpanda_node_group.arn
}

output "k8s_cluster_role_arn" {
  value = aws_iam_role.k8s_cluster.arn
}

output "agent_instance_profile_arn" {
  value = aws_iam_instance_profile.redpanda_agent.arn
}

output "cloud_storage_bucket_arn" {
  value = aws_s3_bucket.redpanda_cloud_storage.arn
}

output "rpsql_cloud_storage_bucket_arn" {
  value       = var.enable_redpanda_sql ? aws_s3_bucket.rpsql[0].arn : null
  description = "ARN of the module-managed S3 bucket used for Redpanda SQL cloud storage"
}

output "management_bucket_arn" {
  value = aws_s3_bucket.management.arn
}

output "dynamodb_table_arn" {
  value = aws_dynamodb_table.terraform_locks.arn
}

output "vpc_arn" {
  value = data.aws_vpc.redpanda.arn
}

output "private_subnet_ids" {
  value       = jsonencode([for o in data.aws_subnet.private : o["arn"]])
  description = <<-DESC
  DEPRECATED. Despite the name, this output returns the private subnet ARNs
  encoded as a JSON string (legacy behavior). Use `private_subnet_arns`
  for a list of ARNs and `private_subnet_id_list` for a list of subnet IDs.
  This output will be removed in a future release.
  DESC
  precondition {
    condition     = length(data.aws_subnet.private) > 0
    error_message = "Either the variable private_subnet_cidrs or private_subnet_ids is required."
  }
}

output "private_subnet_id_list" {
  description = "List of private subnet IDs (works for both BYOVPC and module-created subnets)"
  value       = [for s in data.aws_subnet.private : s.id]
  precondition {
    condition     = length(data.aws_subnet.private) > 0
    error_message = "Either the variable private_subnet_cidrs or private_subnet_ids is required."
  }
}

output "redpanda_agent_security_group_arn" {
  value       = aws_security_group.redpanda_agent.arn
  description = "ID of the redpanda agent security group"
}

output "connectors_security_group_arn" {
  value       = aws_security_group.connectors.arn
  description = "Connectors security group ARN"
}

output "redpanda_connect_security_group_arn" {
  value       = var.enable_redpanda_connect ? aws_security_group.redpanda_connect[0].arn : null
  description = "Redpanda Connect security group ARN"
}

output "rpsql_security_group_arn" {
  value       = var.enable_redpanda_sql ? aws_security_group.rpsql[0].arn : null
  description = "Redpanda SQL security group ARN"
}

output "redpanda_node_group_security_group_arn" {
  value       = aws_security_group.redpanda_node_group.arn
  description = "Redpanda Node Group security group ARN"
}

output "utility_security_group_arn" {
  value       = aws_security_group.utility.arn
  description = "Utility security group ARN"
}

output "cluster_security_group_arn" {
  value       = aws_security_group.cluster.arn
  description = "EKS cluster security group"
}

output "node_security_group_arn" {
  value       = aws_security_group.node.arn
  description = "EKS node shared security group"
}

output "byovpc_rpk_user_policy_arns" {
  value       = var.create_rpk_user ? jsonencode([aws_iam_policy.byovpc_rpk_user_1[0].arn, aws_iam_policy.byovpc_rpk_user_2[0].arn]) : jsonencode([])
  description = "ARNs of policies associated with the 'rpk user'. Can be used by Redpanda engineers to the assume the role and test provisioning with more limited access."
}

output "permissions_boundary_policy_arn" {
  value       = aws_iam_policy.agent_permission_boundary.arn
  description = "ARN of the policy boundary which is required to be included on any roles created by the Redpanda agent"
}

output "private_subnet_arns" {
  description = "List of private subnet ARNs"
  value = [
    for subnet in aws_subnet.private : subnet.arn
  ]
  precondition {
    condition     = length(data.aws_subnet.private) > 0
    error_message = "Either the variable private_subnet_cidrs or private_subnet_ids is required."
  }
}