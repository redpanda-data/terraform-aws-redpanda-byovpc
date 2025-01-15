data "aws_iam_policy_document" "connectors_node_group_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "connectors_node_group" {
  name_prefix           = "${var.common_prefix}-connect-"
  path                  = "/"
  force_detach_policies = true
  tags = merge(
    var.default_tags,
    {
      "redpanda-client" = "connectors"
    }
  )
  assume_role_policy = data.aws_iam_policy_document.connectors_node_group_trust.json
}

resource "aws_iam_instance_profile" "connectors_node_group" {
  name_prefix = "${var.common_prefix}-connect-"
  path        = "/"
  role        = aws_iam_role.connectors_node_group.name
  tags = merge(
    var.default_tags,
    {
      "redpanda-client" = "connectors"
    }
  )
}

resource "aws_iam_role_policy_attachment" "connectors_node_group" {
  for_each = {
    "1" = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    "2" = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    "3" = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  }
  policy_arn = each.value
  role       = aws_iam_role.connectors_node_group.name
}
