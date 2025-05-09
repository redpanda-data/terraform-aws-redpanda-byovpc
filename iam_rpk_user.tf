# The employee (or automated tooling) that will be responsible for running `rpk cloud byoc aws apply|destroy` is
# referred to as the "RPK User". The policies defined in this file are provided for documentation purposes only.
# You may grant your "RPK User" these actions in any way you wish in accordance with the norms of your organization.
#
# The RPK User must have a minimum set of permissions for creating|destroying the Redpanda Agent VM. Once the VM is
# created it will handle the remaining provisioning using the permissions granted in iam_redpanda_agent.tf.
#
# In addition to provisioning the Redpanda Agent VM some validation is performed by `rpk cloud byoc aws apply`. The
# goal of the validation logic is to verify that the customer provided resources have been configured correctly (e.g.
# is the redpanda agent granted the necessary actions? On the appropriate resources? Is the CIDR range sufficient?)
# So that these validations may be performed certain read actions are also suggested for the RPK User.

data "aws_iam_policy_document" "byovpc_rpk_user_1" {
  count = var.create_rpk_user ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole",
    ]
    resources = [
      aws_iam_role.redpanda_agent.arn
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateLaunchTemplate",
    ]
    resources = [
      # the ID of the launch template is not known until after the cluster has been created and does not support user
      # specification of the id or an id prefix
      "arn:*:ec2:${var.region}:${local.aws_account_id}:launch-template/*"
    ]
    dynamic "condition" {
      for_each = var.condition_tags
      content {
        test     = "StringEquals"
        variable = "aws:RequestTag/${condition.key}"
        values = [
          condition.value,
        ]
      }
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcAttribute",
    ]
    resources = [
      data.aws_vpc.redpanda.arn
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeSubnets",
    ]
    resources = concat(tolist(aws_subnet.public.*.arn), tolist(aws_subnet.private.*.arn))
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
    ]
    resources = [
      "arn:aws:iam::${local.aws_account_id}:policy/redpanda-connectors-secrets-manager-*",
      "arn:aws:iam::${local.aws_account_id}:policy/redpanda-*-redpanda-connect-secrets-manager",
      "arn:aws:iam::${local.aws_account_id}:policy/redpanda-*-redpanda-connect-pipeline-secrets-manager",
      "arn:aws:iam::${local.aws_account_id}:policy/redpanda-console-secrets-manager-*",
      "arn:aws:iam::${local.aws_account_id}:policy/redpanda-cloud-storage-manager-*",
      "arn:aws:iam::${local.aws_account_id}:policy/redpanda-*-secrets-reader-operator",
      "arn:aws:iam::${local.aws_account_id}:policy/redpanda-*-cluster-secrets-reader",
      aws_iam_policy.cluster_autoscaler_policy.arn,
      aws_iam_policy.redpanda_agent["1"].arn,
      aws_iam_policy.redpanda_agent["2"].arn,
      aws_iam_policy.redpanda_agent["3"].arn,
      aws_iam_policy.aws_ebs_csi_driver_policy.arn,
      aws_iam_policy.load_balancer_controller_policy["1"].arn,
      aws_iam_policy.load_balancer_controller_policy["2"].arn,
      aws_iam_policy.external_dns_policy.arn,
      aws_iam_policy.cert_manager.arn,
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:DeletePolicy",
    ]
    resources = [
      "arn:aws:iam::${local.aws_account_id}:policy/redpanda-cloud-storage-manager-*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:GetInstanceProfile",
    ]
    resources = concat([
      aws_iam_instance_profile.redpanda_agent.arn,
      aws_iam_instance_profile.redpanda_node_group.arn,
      aws_iam_instance_profile.utility.arn,
      aws_iam_instance_profile.connectors_node_group.arn,
    ], var.enable_redpanda_connect ? [aws_iam_instance_profile.redpanda_connect_node_group[0].arn] : [])
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListRolePolicies",
    ]
    resources = concat([
      aws_iam_role.redpanda_node_group.arn,
      aws_iam_role.redpanda_agent.arn,
      "arn:aws:iam::${local.aws_account_id}:role/redpanda-cloud-storage-manager-*",
      "arn:aws:iam::${local.aws_account_id}:role/redpanda-console-secrets-manager-*",
      "arn:aws:iam::${local.aws_account_id}:role/redpanda-connectors-secrets-manager-*",
      "arn:aws:iam::${local.aws_account_id}:role/redpanda-*-redpanda-connect",
      "arn:aws:iam::${local.aws_account_id}:role/redpanda-*-redpanda-connect-pipeline",
      "arn:aws:iam::${local.aws_account_id}:role/redpanda-*-operator-role",
      aws_iam_role.k8s_cluster.arn,
      aws_iam_role.redpanda_utility_node_group.arn,
      aws_iam_role.connectors_node_group.arn,
      "arn:aws:iam::${local.aws_account_id}:role/${var.common_prefix}-rpk-user-role-*",
    ], var.enable_redpanda_connect ? [aws_iam_role.redpanda_connect_node_group[0].arn] : [])
  }

  statement {
    effect = "Allow"
    actions = [
      "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:SetInstanceProtection",
      "autoscaling:DeleteAutoScalingGroup",
      "autoscaling:StartInstanceRefresh",
      "autoscaling:CancelInstanceRefresh",
      "autoscaling:CreateAutoScalingGroup",
    ]
    resources = [
      "arn:aws:autoscaling:*:${local.aws_account_id}:autoScalingGroup:*:autoScalingGroupName/redpanda*",
    ]
    dynamic "condition" {
      for_each = var.condition_tags
      content {
        test     = "StringEquals"
        variable = "autoscaling:ResourceTag/${condition.key}"
        values = [
          condition.value,
        ]
      }
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateLaunchTemplateVersion",
      "ec2:DeleteLaunchTemplate",
      "ec2:DeleteTags",
    ]
    resources = [
      # the ID of the launch template is not known until after the cluster has been created and does not support user
      # specification of the id or an id prefix
      "arn:aws:ec2:*:${local.aws_account_id}:launch-template/*"
    ]
    dynamic "condition" {
      for_each = var.condition_tags
      content {
        test     = "StringEquals"
        variable = "aws:ResourceTag/${condition.key}"
        values = [
          condition.value,
        ]
      }
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
    ]
    resources = [
      # the ID of the launch template is not known until after the cluster has been created and does not support user
      # specification of the id or an id prefix
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:launch-template/*",

      # the ID of the instance is not known until after the cluster has been created (and even after that is subject to
      # change) and does not support user specification of the id or an id prefix
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:instance/*",

      # The ID of the volume is not known until after the cluster has been created and does not support user
      # specification of the id or an id prefix
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:volume/*",

      "arn:aws:ec2:${var.region}::image/*",

      "arn:aws:ec2:${var.region}:${local.aws_account_id}:placement-group/redpanda-*-pg",

      # the ID of the VPC endpoint service is not known until after the cluster has been created and does not support
      # user specification of the id or an id prefix
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:vpc-endpoint-service/*",

      # The ID of the network interface is not known until after the cluster has been created and does not support
      # user specification of the id or an id prefix
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:network-interface/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values = [
        "CreateLaunchTemplate",
        "RunInstances",
        "CreateVpcEndpointServiceConfiguration",
        "CreatePlacementGroup"
      ]
    }
  }
}

data "aws_iam_policy_document" "byovpc_rpk_user_2" {
  count = var.create_rpk_user ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      # The following autoscaling actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonec2autoscaling.html
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeScalingActivities",

      # The following ec2 actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonec2.html
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeNatGateways",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribePrefixLists",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroupRules",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcEndpointServices",
      "ec2:DescribeVpcEndpoints",

      # The following actions are used to validate that the current user has the requisite permissions to run byoc apply
      # I do not know in advance what role the current user will be using, therefore this is wildcarded, but if the
      # rpk user has permission to list attached policies on their current role, get those policies, and retrieve the
      # default version of those policies, that is sufficient
      "iam:ListAttachedRolePolicies",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjects",
      "s3:DeleteObjectTagging",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:PutObjectTagging",
      "s3:GetObjectVersion",
      "s3:ListBucketVersions",
      "s3:GetBucketVersioning",
    ]
    resources = [
      aws_s3_bucket.management.arn,
      "${aws_s3_bucket.management.arn}/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning",
    ]
    resources = [
      aws_s3_bucket.redpanda_cloud_storage.arn,
      "${aws_s3_bucket.redpanda_cloud_storage.arn}/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [
      aws_dynamodb_table.terraform_locks.arn,
      "${aws_dynamodb_table.terraform_locks.arn}/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:RunInstances",
    ]
    resources = [
      "arn:aws:ec2:*::image/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:RunInstances",
    ]
    resources = [
      # the ID of the launch template is not known until after the cluster has been created and does not support user
      # specification of the id or an id prefix
      "arn:aws:ec2:*:${local.aws_account_id}:launch-template/*",
    ]
    dynamic "condition" {
      for_each = var.condition_tags
      content {
        test     = "StringEquals"
        variable = "aws:ResourceTag/${condition.key}"
        values = [
          condition.value,
        ]
      }
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:RunInstances",
    ]
    resources = concat([
      aws_security_group.redpanda_agent.arn
    ], tolist(aws_subnet.public.*.arn), tolist(aws_subnet.private.*.arn))
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:RunInstances",
    ]
    resources = [
      "arn:aws:ec2:*:${local.aws_account_id}:instance/*",
      "arn:aws:ec2:*:${local.aws_account_id}:network-interface/*",
      "arn:aws:ec2:*:${local.aws_account_id}:volume/*",
    ]
    dynamic "condition" {
      for_each = var.condition_tags
      content {
        test     = "StringEquals"
        variable = "aws:RequestTag/${condition.key}"
        values = [
          condition.value,
        ]
      }
    }
  }

  statement {
    # The user may create policy documents as long as they have the required tags
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
      "iam:TagPolicy"
    ]
    resources = ["*"]
    dynamic "condition" {
      for_each = var.condition_tags
      content {
        test     = "StringEquals"
        variable = "aws:RequestTag/${condition.key}"
        values = [
          condition.value,
        ]
      }
    }
  }
}

resource "aws_iam_policy" "byovpc_rpk_user_1" {
  count       = var.create_rpk_user ? 1 : 0
  name_prefix = "${var.common_prefix}-rpk-user-1_"
  path        = "/"
  description = "Minimum permissions required for RPK user for BYO VPC"
  policy      = data.aws_iam_policy_document.byovpc_rpk_user_1[0].json
  tags        = var.default_tags
}

resource "aws_iam_policy" "byovpc_rpk_user_2" {
  count       = var.create_rpk_user ? 1 : 0
  name_prefix = "${var.common_prefix}-rpk-user-2_"
  path        = "/"
  description = "Minimum permissions required for RPK user for BYO VPC"
  policy      = data.aws_iam_policy_document.byovpc_rpk_user_2[0].json
  tags        = var.default_tags
}
