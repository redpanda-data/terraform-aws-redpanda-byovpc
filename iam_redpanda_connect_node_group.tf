data "aws_iam_policy_document" "redpanda_connect_node_group_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "redpanda_connect_node_group" {
  count                 = var.enable_redpanda_connect ? 1 : 0
  name_prefix           = "${var.common_prefix}-rpcn-"
  path                  = "/"
  force_detach_policies = true
  tags = merge(
    var.default_tags,
    {
      "redpanda-client" = "rp-connect"
    }
  )
  assume_role_policy = data.aws_iam_policy_document.redpanda_connect_node_group_trust.json
}

resource "aws_iam_instance_profile" "redpanda_connect_node_group" {
  count       = var.enable_redpanda_connect ? 1 : 0
  name_prefix = "${var.common_prefix}-rpcn-"
  path        = "/"
  role        = aws_iam_role.redpanda_connect_node_group[0].name
  tags = merge(
    var.default_tags,
    {
      "redpanda-client" = "rp-connect"
    }
  )
}

resource "aws_iam_role_policy_attachment" "redpanda_connect_node_group" {
  for_each = var.enable_redpanda_connect ? {
    "1" = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    "2" = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    "3" = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  } : {}
  policy_arn = each.value
  role       = aws_iam_role.redpanda_connect_node_group[0].name
}
