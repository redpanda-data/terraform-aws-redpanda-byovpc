data "aws_iam_policy_document" "k8s_cluster_trust" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "k8s_cluster" {
  assume_role_policy    = data.aws_iam_policy_document.k8s_cluster_trust.json
  force_detach_policies = true
  max_session_duration  = 3600
  name_prefix           = "${var.common_prefix}-cluster-"
  path                  = "/"
  tags                  = var.default_tags
}

resource "aws_iam_role_policy_attachment" "k8s_cluster" {
  for_each = {
    "1" = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
    "2" = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  }
  policy_arn = each.value
  role       = aws_iam_role.k8s_cluster.name
}
