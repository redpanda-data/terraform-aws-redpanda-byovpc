data "aws_iam_policy_document" "redpanda_agent1" {
  statement {
    effect = "Allow"
    actions = [
      # The following autoscaling actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonec2autoscaling.html
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeTags",
      "autoscaling:DescribeTerminationPolicyTypes",
      "autoscaling:DescribeInstanceRefreshes",
      "autoscaling:DescribeLaunchConfigurations",

      # The following cloudwatch actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazoncloudwatch.html
      "cloudwatch:GetMetricData",

      # The following ec2 actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonec2.html
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribePlacementGroups",
      "ec2:DescribeVpcs",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSecurityGroupRules",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNatGateways",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeNetworkAcls",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeVpcEndpoints",
      "ec2:DescribeVpcEndpointServices",
      "ec2:DescribeVolumes",

      # The following elasticloadbalancing actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_awselasticloadbalancingv2.html
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeTargetGroupAttributes",

      # The following iam actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_awsidentityandaccessmanagementiam.html
      "iam:ListPolicies",
      "iam:ListRoles",

      # The following route53 actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonroute53.html
      "route53:CreateHostedZone",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "route53:GetChange",
    ]
    resources = [
      # the ID of the change is not known prior to creating the change and does not support user specification of the id
      # or an id prefix
      "arn:aws:route53:::change/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "route53:GetHostedZone",
      "route53:GetDNSSEC",
      "route53:ListTagsForResource",
      "route53:ListResourceRecordSets",
      "route53:ChangeResourceRecordSets",
      "route53:ChangeTagsForResource",
      "route53:DeleteHostedZone",
    ]
    resources = [
      # the ID of the hosted zone is not known until after the cluster has been created and does not support user
      # specification of the id or an id prefix
      "arn:aws:route53:::hostedzone/*"
    ]
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
      "ec2:CreateLaunchTemplate",
    ]
    resources = [
      # the ID of the launch template is not known until after the cluster has been created and does not support user
      # specification of the id or an id prefix
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:launch-template/*"
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
      "ec2:CreatePlacementGroup",
    ]
    resources = [
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:placement-group/redpanda-*-pg"
    ]
    dynamic "condition" {
      for_each = var.condition_tags
      content {
        test = "StringEquals"

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
      "ec2:CreateLaunchTemplateVersion"
    ]
    resources = [
      # the ID of the launch template is not known until after the cluster has been created and does not support user
      # specification of the id or an id prefix
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:launch-template/*"
    ]
    dynamic "condition" {
      for_each = var.condition_tags
      content {
        test     = "StringEquals"
        variable = "ec2:ResourceTag/${condition.key}"
        values = [
          condition.value,
        ]
      }
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DeletePlacementGroup",
    ]
    resources = [
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:placement-group/redpanda-*-pg"
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

  statement {
    effect = "Allow"
    actions = [
      "ec2:RunInstances",
    ]
    resources = concat(
      [
        # the ID of the instance is not known until after the cluster has been created (and even after that is subject to
        # change) and does not support user specification of the id or an id prefix
        "arn:aws:ec2:*:${local.aws_account_id}:instance/*",

        # The ID of the network interface is not known until after the cluster has been created and does not support
        # user specification of the id or an id prefix
        "arn:aws:ec2:*:${local.aws_account_id}:network-interface/*",

        # The ID of the volume is not known until after the cluster has been created and does not support user
        # specification of the id or an id prefix
        "arn:aws:ec2:*:${local.aws_account_id}:volume/*",

        "arn:aws:ec2:*:${local.aws_account_id}:security-group/*",

        # the ID of the launch template is not known until after the cluster has been created and does not support user
        # specification of the id or an id prefix
        "arn:aws:ec2:*:${local.aws_account_id}:launch-template/*",

        "arn:aws:ec2:*::image/*",
      ],
    [for o in data.aws_subnet.private : o["arn"]])
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DeleteLaunchTemplate",
      "ec2:ModifyLaunchTemplate",
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
        variable = "ec2:ResourceTag/${condition.key}"
        values = [
          condition.value,
        ]
      }
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "eks:*",
    ]
    resources = [
      "arn:aws:eks:*:${local.aws_account_id}:cluster/redpanda-*",
      "arn:aws:eks:*:${local.aws_account_id}:addon/*",
    ]
  }

  statement {
    sid    = "RedpandaAgentInstanceProfile"
    effect = "Allow"
    actions = [
      "iam:GetInstanceProfile",
      "iam:TagInstanceProfile",
    ]
    resources = [
      aws_iam_instance_profile.redpanda_agent.arn,
      aws_iam_instance_profile.redpanda_node_group.arn,
      aws_iam_instance_profile.utility.arn,
      aws_iam_instance_profile.connectors_node_group.arn
    ]
  }
}

data "aws_iam_policy_document" "redpanda_agent2" {
  statement {
    effect = "Allow"
    actions = [
      "iam:GetOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:CreateOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
    ]
    resources = [
      "arn:aws:iam::${local.aws_account_id}:oidc-provider/oidc.eks.*.amazonaws.com",
      "arn:aws:iam::${local.aws_account_id}:oidc-provider/oidc.eks.*.amazonaws.com/id/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:ListPolicyTags",
    ]
    resources = [
      aws_iam_policy.aws_ebs_csi_driver_policy.arn,
      aws_iam_policy.cert_manager.arn,
      aws_iam_policy.external_dns_policy.arn,
      aws_iam_policy.load_balancer_controller_policy["1"].arn,
      aws_iam_policy.load_balancer_controller_policy["2"].arn,
      # redpanda_agent1 and redpanda_agent2, cannot be referenced by object due to cycle
      "arn:aws:iam::${local.aws_account_id}:policy/${var.common_prefix}-agent-*-*",
      aws_iam_policy.cluster_autoscaler_policy.arn,
      "arn:aws:iam::${local.aws_account_id}:policy/redpanda-connectors-secrets-manager-*",
      "arn:aws:iam::${local.aws_account_id}:policy/redpanda-console-secrets-manager-*",
      "arn:aws:iam::${local.aws_account_id}:policy/redpanda-cloud-storage-manager-*",
      "arn:aws:iam::aws:policy/Amazon*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:PassRole",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListRolePolicies",
      "iam:ListRoleTags",
    ]
    resources = [
      "arn:aws:iam::${local.aws_account_id}:role/redpanda-cloud-storage-manager-*",
      "arn:aws:iam::${local.aws_account_id}:role/redpanda-console-secrets-manager-*",
      "arn:aws:iam::${local.aws_account_id}:role/redpanda-connectors-secrets-manager-*",
      aws_iam_role.redpanda_agent.arn,
      aws_iam_role.redpanda_node_group.arn,
      aws_iam_role.redpanda_utility_node_group.arn,
      aws_iam_role.connectors_node_group.arn,
      aws_iam_role.k8s_cluster.arn,
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:*",
    ]
    resources = [
      aws_s3_bucket.management.arn,
      "${aws_s3_bucket.management.arn}/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:List*",
      "s3:Get*",
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
      "autoscaling:*",
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
      "ec2:TerminateInstances",
      "ec2:RebootInstances",
    ]
    resources = [
      # the ID of the instance is not known until after the cluster has been created (and even after that is subject to
      # change) and does not support user specification of the id or an id prefix
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:instance/*"
    ]
    dynamic "condition" {
      for_each = var.condition_tags
      content {
        test     = "StringEquals"
        variable = "ec2:ResourceTag/${condition.key}"
        values = [
          condition.value,
        ]
      }
    }
  }
}

statement {
  sid    = "RedpandaAgentEKSOIDCProviderCACertThumbprintUpdate"
  effect = "Allow"
  actions = [
    "iam:UpdateOpenIDConnectProviderThumbprint",
  ]
  resources = [
    "arn:aws:iam::${local.aws_account_id}:oidc-provider/oidc.eks.*.amazonaws.com",
    "arn:aws:iam::${local.aws_account_id}:oidc-provider/oidc.eks.*.amazonaws.com/id/*",
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

# The agent will need to create 3 roles that can only be created after the kubernetes cluster has been created:
# console secretes manager
# connectors secrets manager
# cloud storage manager
#
# The reason these roles must be created after the kubernetes cluster is that they configure an assume role policy
# which depends on the oidc provider for the cluster. This is unique to the cluster and cannot be created or known
# in advance.
#
# To alleviate the risk of allowing the agent to create roles we define a permission boundary such that any roles
# created by the agent cannot grant permissions beyond the cope of the permission boundary.
# ref: https://aws.amazon.com/blogs/security/when-and-where-to-use-iam-permissions-boundaries/
# The agent can create roles, but those roles are have these maximum boundaries
data "aws_iam_policy_document" "agent_permission_boundary" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.region}:*:secret:redpanda/*/connectors/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:*",
    ]
    resources = [
      aws_s3_bucket.redpanda_cloud_storage.arn,
      "${aws_s3_bucket.redpanda_cloud_storage.arn}/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:RestoreSecret",
      "secretsmanager:RotateSecret",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
      "secretsmanager:UpdateSecret"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.region}:*:secret:redpanda/*/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      # The following secretsmanager actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_awssecretsmanager.html
      "secretsmanager:ListSecrets"
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = data.aws_s3_bucket.source_bucket
    content {
      effect = "Allow"
      actions = [
        "s3:Get*",
        "s3:List*"
      ]
      resources = [
        "${statement.value.arn}/*",
        statement.value.arn
      ]
    }
  }
}

resource "aws_iam_policy" "agent_permission_boundary" {
  name_prefix = "${var.common_prefix}-agent-boundary-"
  policy      = data.aws_iam_policy_document.agent_permission_boundary.json
  tags = var.default_tags
}

data "aws_iam_policy_document" "agent_permissions_boundary_scoped_iam" {
  statement {
    # The agent may create policy documents as long as they have the required tags
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
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

  statement {
    # The agent may modify only these 3 policy documents
    effect = "Allow"
    actions = [
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy",
      "iam:DeletePolicy",
      "iam:SetDefaultPolicyVersion",
    ]
    resources = [
      "arn:aws:iam::${local.aws_account_id}:policy/redpanda-cloud-storage-manager-*",
      "arn:aws:iam::${local.aws_account_id}:policy/redpanda-console-secrets-manager-*",
      "arn:aws:iam::${local.aws_account_id}:policy/redpanda-connectors-secrets-manager-*",
    ]
  }

  statement {
    # The agent will be permitted to create roles, but only if they contain the permission boundary
    effect = "Allow"
    actions = [
      "iam:CreateRole"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values = [
        aws_iam_policy.agent_permission_boundary.arn
      ]
    }
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
    # The three roles created/managed by the agent may be modified but must retain their permission boundary
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
    ]
    resources = [
      "arn:aws:iam::${local.aws_account_id}:role/redpanda-cloud-storage-manager-*",
      "arn:aws:iam::${local.aws_account_id}:role/redpanda-console-secrets-manager-*",
      "arn:aws:iam::${local.aws_account_id}:role/redpanda-connectors-secrets-manager-*",
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values = [
        aws_iam_policy.agent_permission_boundary.arn
      ]
    }
  }

  statement {
    # The three roles created/managed by the agent may be modified or deleted
    effect = "Allow"
    actions = [
      "iam:TagRole",
      "iam:UntagRole",
      "iam:DeleteRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
    ]
    resources = [
      "arn:aws:iam::${local.aws_account_id}:role/redpanda-cloud-storage-manager-*",
      "arn:aws:iam::${local.aws_account_id}:role/redpanda-console-secrets-manager-*",
      "arn:aws:iam::${local.aws_account_id}:role/redpanda-connectors-secrets-manager-*",
    ]
  }

  statement {
    # The permission boundary may not be removed from any role
    effect = "Deny"
    actions = [
      "iam:DeleteRolePermissionsBoundary"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values = [
        aws_iam_policy.agent_permission_boundary.arn
      ]
    }
  }

  statement {
    # Modification of the permission boundary in any way is prohibited
    effect = "Deny"
    actions = [
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:DetachRolePolicy",
      "iam:SetDefaultPolicyVersion"
    ]
    resources = [
      aws_iam_policy.agent_permission_boundary.arn
    ]
  }
}

data "aws_iam_policy_document" "redpanda_agent_private_link" {
  count = var.enable_private_link ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateListener",
    ]
    resources = [
      # the ID of the load balancer is not known until after the cluster has been created
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:loadbalancer/net/*"
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
      "elasticloadbalancing:AddTags",
    ]
    resources = [
      # the ID of the load balancer is not known until after the cluster has been created
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:loadbalancer/net/*",

      # the ID of the listener is not known until after the cluster has been created
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:listener/net/*",

      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*-rp-*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*-kf-*/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*-seed/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*-console/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "elasticloadbalancing:CreateAction"
      values = [
        "CreateListener",
        "CreateTargetGroup",
      ]
    }
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
      "elasticloadbalancing:CreateTargetGroup",
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*-rp-*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*-kf-*/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*-seed/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*-console/*"
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
      "elasticloadbalancing:DeleteListener",
    ]
    resources = [
      # the ID of the listener is not known until after the cluster has been created
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:listener/net/*"
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
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets",
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*-rp-*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*-kf-*/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*-seed/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*-console/*"
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
      "ec2:CreateVpcEndpointServiceConfiguration",
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
    resources = [
      # the ID of the VPC endpoint service is not known until after the cluster has been created and does not support
      # user specification of the id or an id prefix
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:vpc-endpoint-service/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DeleteVpcEndpointServiceConfigurations",
      "ec2:ModifyVpcEndpointServiceConfiguration",
      "ec2:ModifyVpcEndpointServicePermissions",
      "ec2:AcceptVpcEndpointConnections",
      "ec2:CreateVpcEndpointConnectionNotification",
      "ec2:DeleteVpcEndpointConnectionNotifications",
      "ec2:ModifyVpcEndpointConnectionNotification",
      "ec2:ModifyVpcEndpointServicePayerResponsibility",
      "ec2:RejectVpcEndpointConnections",
      "ec2:StartVpcEndpointServicePrivateDnsVerification",
      "ec2:DescribeVpcEndpointServicePermissions",
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
    resources = [
      # the ID of the VPC endpoint service is not known until after the cluster has been created and does not support
      # user specification of the id or an id prefix
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:vpc-endpoint-service/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      # The following ec2 actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonec2.html
      "ec2:DescribeVpcEndpointServiceConfigurations",
      "ec2:DescribeVpcEndpointConnectionNotifications",
      "ec2:DescribeVpcEndpointConnections",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "redpanda_agent_trust_ec2" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "redpanda_agent" {
  name_prefix        = "${var.common_prefix}-agent-"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.redpanda_agent_trust_ec2.json
  tags = var.default_tags
}

resource "aws_iam_instance_profile" "redpanda_agent" {
  name_prefix = "${var.common_prefix}-agent-"
  role        = aws_iam_role.redpanda_agent.name
  tags = var.default_tags
}

resource "aws_iam_policy" "redpanda_agent" {
  for_each = {
    "1" = data.aws_iam_policy_document.redpanda_agent1
    "2" = data.aws_iam_policy_document.redpanda_agent2
    "3" = data.aws_iam_policy_document.agent_permissions_boundary_scoped_iam
  }
  name_prefix = "${var.common_prefix}-agent-${each.key}-"
  policy      = each.value.json
  tags = var.default_tags
}

resource "aws_iam_role_policy_attachment" "redpanda_agent" {
  for_each = {
    "1" = aws_iam_policy.redpanda_agent["1"].arn,
    "2" = aws_iam_policy.redpanda_agent["2"].arn,
    "3" = aws_iam_policy.redpanda_agent["3"].arn
  }
  role       = aws_iam_role.redpanda_agent.name
  policy_arn = each.value
}

resource "aws_iam_policy" "redpanda_agent_private_link" {
  count       = var.enable_private_link ? 1 : 0
  name_prefix = "${var.common_prefix}-agent-pl-"
  policy      = data.aws_iam_policy_document.redpanda_agent_private_link[0].json
  tags = var.default_tags
}

resource "aws_iam_role_policy_attachment" "redpanda_agent_private_link" {
  count      = var.enable_private_link ? 1 : 0
  role       = aws_iam_role.redpanda_agent.name
  policy_arn = aws_iam_policy.redpanda_agent_private_link[0].arn
}
