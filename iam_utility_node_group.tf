data "aws_iam_policy_document" "cluster_autoscaler_policy" {
  statement {
    effect = "Allow"
    actions = [
      # The following autoscaling actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonec2autoscaling.html
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",

      # The following ec2 actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonec2.html
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
    ]
    resources = [
      "arn:aws:autoscaling:${var.region}:${local.aws_account_id}:autoScalingGroup:*:autoScalingGroupName/redpanda-*",
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
}

resource "aws_iam_policy" "cluster_autoscaler_policy" {
  name_prefix = "${var.common_prefix}-rp-autoscaler-"
  policy      = data.aws_iam_policy_document.cluster_autoscaler_policy.json
}

data "aws_iam_policy_document" "external_dns" {
  statement {
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
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
      # The following route53 actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonroute53.html
      "route53:ListHostedZones",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "external_dns_policy" {
  name_prefix = "${var.common_prefix}-external_dns_policy-"
  path        = "/"
  description = "Policy to enable external-dns to manage hosted zones"
  policy      = data.aws_iam_policy_document.external_dns.json
  tags = var.default_tags
}

data "aws_iam_policy_document" "aws_ebs_csi_driver" {
  statement {
    effect = "Allow"
    actions = [
      # The following ec2 actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonec2.html
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeSnapshots",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags"
    ]
    resources = [
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:volume/*",
      "arn:aws:ec2:${var.region}::snapshot/*"
    ]
    condition {
      test = "StringEquals"
      values = ["CreateVolume",
      "CreateSnapshot"]
      variable = "ec2:CreateAction"
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:AttachVolume",
      "ec2:CreateSnapshot",
      "ec2:DeleteTags",
      "ec2:DetachVolume",
      "ec2:ModifyVolume",
    ]
    resources = [
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:volume/*",
      "arn:aws:ec2:${var.region}::snapshot/*",
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:instance/*"
    ]
  }
  dynamic "statement" {
    for_each = {
      "aws:RequestTag/ebs.csi.aws.com/cluster" : "true",
      "aws:RequestTag/CSIVolumeName" : "*",
      "aws:RequestTag/kubernetes.io/cluster/*" : "owned",
    }
    content {
      effect = "Allow"
      actions = [
        "ec2:CreateVolume"
      ]
      resources = [
        "arn:aws:ec2:${var.region}:${local.aws_account_id}:volume/*",
      ]
      condition {
        test     = "StringLike"
        variable = statement.key
        values   = [statement.value]
      }
    }
  }
  dynamic "statement" {
    for_each = {
      "ec2:ResourceTag/ebs.csi.aws.com/cluster" : "true",
      "ec2:ResourceTag/CSIVolumeName" : "*",
      "ec2:ResourceTag/kubernetes.io/cluster/*" : "owned",
    }
    content {
      effect = "Allow"
      actions = [
        "ec2:DeleteVolume"
      ]
      resources = [
        "arn:aws:ec2:${var.region}:${local.aws_account_id}:volume/*",
      ]
      condition {
        test     = "StringLike"
        variable = statement.key
        values   = [statement.value]
      }
    }
  }
  dynamic "statement" {
    for_each = {
      "ec2:ResourceTag/CSIVolumeSnapshotName" : "*",
      "ec2:ResourceTag/ebs.csi.aws.com/cluster" : "true",
    }
    content {
      effect = "Allow"
      actions = [
        "ec2:DeleteSnapshot"
      ]
      resources = [
        "arn:aws:ec2:${var.region}::snapshot/*"
      ]
      condition {
        test     = "StringLike"
        variable = "ec2:ResourceTag/CSIVolumeSnapshotName"
        values   = ["*"]
      }
    }
  }
}

resource "aws_iam_policy" "aws_ebs_csi_driver_policy" {
  name_prefix = "${var.common_prefix}-aws_ebs_csi_driver-"
  path        = "/"
  description = "Policy to enable EKS nodes to manage and create EBS volumes using the AWS EBS CSI driver"

  policy = data.aws_iam_policy_document.aws_ebs_csi_driver.json
  tags = var.default_tags
}

data "aws_iam_policy_document" "load_balancer_controller_1" {
  statement {
    effect = "Allow"
    actions = [
      # The following ec2 actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonec2.html
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:DescribeCoipPools",

      # The following elasticloadbalancing actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_awselasticloadbalancingv2.html
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:SetWebAcl",

      # The following acm actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_awscertificatemanager.html
      "acm:ListCertificates",

      # The following iam actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_awsidentityandaccessmanagementiam.html
      "iam:ListServerCertificates",

      # The following shield actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_awsshield.html
      "shield:GetSubscriptionState",
      "shield:CreateProtection",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:GetCoipPoolUsage",
    ]
    resources = [
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:coip-pool/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "cognito-idp:DescribeUserPoolClient",
    ]
    resources = [
      "arn:aws:cognito-idp:${var.region}:${local.aws_account_id}:userpool/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "acm:DescribeCertificate",
    ]
    resources = [
      "arn:aws:acm:${var.region}:${local.aws_account_id}:certificate/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:GetServerCertificate",
    ]
    resources = [
      "arn:aws:iam::${local.aws_account_id}:server-certificate/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "shield:DescribeProtection",
      "shield:DeleteProtection",
    ]
    resources = [
      "arn:aws:shield::${local.aws_account_id}:protection/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = [
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:security-group/*"
    ]
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["redpanda-*"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["redpanda-*"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
    ]
    resources = [
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:security-group/*",
      "arn:aws:ec2:${var.region}:${local.aws_account_id}:security-group-rule/*"
    ]
    condition {
      test     = "ArnEquals"
      variable = "ec2:Vpc"
      values   = [data.aws_vpc.redpanda.arn]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:loadbalancer/app/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:loadbalancer/net/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*"
    ]
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["redpanda-*"]
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
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule",
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:loadbalancer/app/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:loadbalancer/net/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:listener/app/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:listener/net/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:listener-rule/app/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:listener-rule/net/*",
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
      "elasticloadbalancing:CreateListener", # TODO: supports redpanda-managed + custom tag + arn:aws:elasticloadbalancing:us-east-2:961547496971:listener/net/k8s-redpanda
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:loadbalancer/app/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:loadbalancer/net/*",
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
      "elasticloadbalancing:RemoveTags",
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:loadbalancer/app/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:loadbalancer/net/*",
    ]
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["redpanda-*"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["redpanda-*"]
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
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:listener/app/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:listener/net/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:listener-rule/app/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:listener-rule/net/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:loadbalancer/app/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:loadbalancer/net/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "elasticloadbalancing:CreateAction"
      values = [
        "CreateListener",
        "CreateTargetGroup",
        "CreateLoadBalancer",
      ]
    }
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["redpanda-*"]
    }
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
}

data "aws_iam_policy_document" "load_balancer_controller_2" {
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DeleteTargetGroup",
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:loadbalancer/app/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:loadbalancer/net/*",
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*"
    ]
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["redpanda-*"]
    }
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
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*"
    ]
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["redpanda-*"]
    }
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

  dynamic "statement" {
    for_each = var.enable_private_link ? ["true"] : []
    content {
      effect = "Allow"
      actions = [
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets",
      ]
      resources = [
        "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*-rp-*",
        "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*-kf-*/*",
        "arn:aws:elasticloadbalancing:${var.region}:${local.aws_account_id}:targetgroup/*-console/*"
      ]
      condition {
        test     = "StringEquals"
        variable = "aws:ResourceTag/redpanda-private-link"
        values   = ["true"]
      }
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
  }
}

resource "aws_iam_policy" "load_balancer_controller_policy" {
  for_each = {
    "1" : data.aws_iam_policy_document.load_balancer_controller_1
    "2" : data.aws_iam_policy_document.load_balancer_controller_2
  }
  name_prefix = "${var.common_prefix}-load_balancer_controller_${each.key}-"
  path        = "/"
  description = "Policy to enable the load balancer controller to expose load balancers"
  policy      = each.value.json
  tags = var.default_tags
}

data "aws_iam_policy_document" "cert_manager" {
  statement {
    effect = "Allow"
    actions = [
      "route53:GetChange",
    ]
    resources = [
      # the ID of the change is not known in advance and does not support user specification of the id or an id prefix
      "arn:aws:route53:::change/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets"
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
      # The following route53 actions do not support resource types
      # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonroute53.html
      "route53:ListHostedZonesByName"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cert_manager" {
  name_prefix = "${var.common_prefix}-cert_manager_policy-"
  path        = "/"
  description = "Policy to enable cert-manager to manage challenges"
  policy      = data.aws_iam_policy_document.cert_manager.json
  tags = var.default_tags
}

data "aws_iam_policy_document" "utility_node_group_trust" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "redpanda_utility_node_group" {
  assume_role_policy    = data.aws_iam_policy_document.utility_node_group_trust.json
  force_detach_policies = true
  name_prefix           = "${var.common_prefix}-util-"
  path                  = "/"
  tags = var.default_tags
}

# Attach policy to utility nodes to be able to update DNS records
resource "aws_iam_role_policy_attachment" "external_dns_utility_nodes" {
  for_each = {
    "1" = aws_iam_policy.cluster_autoscaler_policy.arn
    "2" = aws_iam_policy.external_dns_policy.arn
    "3" = aws_iam_policy.aws_ebs_csi_driver_policy.arn
    "4" = aws_iam_policy.load_balancer_controller_policy["1"].arn
    "5" = aws_iam_policy.load_balancer_controller_policy["2"].arn
    "6" = aws_iam_policy.cert_manager.arn
    "7" = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    "8" = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    "9" = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  }
  policy_arn = each.value
  role       = aws_iam_role.redpanda_utility_node_group.name
}

resource "aws_iam_instance_profile" "utility" {
  name_prefix = "${var.common_prefix}-util-"
  path        = "/"
  role        = aws_iam_role.redpanda_utility_node_group.name
  tags = var.default_tags
}
