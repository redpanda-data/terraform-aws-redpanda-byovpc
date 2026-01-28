data "aws_iam_policy_document" "redpanda_node_group_trust" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "redpanda_node_group" {
  assume_role_policy    = data.aws_iam_policy_document.redpanda_node_group_trust.json
  force_detach_policies = true
  name_prefix           = "${var.common_prefix}-rp-"
  path                  = "/"
  tags                  = var.default_tags
}

resource "aws_iam_instance_profile" "redpanda_node_group" {
  name_prefix = "${var.common_prefix}-rp-"
  path        = "/"
  role        = aws_iam_role.redpanda_node_group.name
  tags        = var.default_tags
}

resource "aws_iam_role_policy_attachment" "redpanda_node_group" {
  for_each = {
    "1" = aws_iam_policy.aws_ebs_csi_driver_policy.arn
    "2" = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    "3" = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    "4" = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  }
  policy_arn = each.value
  role       = aws_iam_role.redpanda_node_group.name
}

# Ensure the EKS node group service-linked role exists
# This is required for EKS managed node groups and may not exist in brand new AWS accounts
# We use null_resource because it gracefully handles both cases:
# - If the role doesn't exist, it creates it
# - If the role already exists, the command succeeds (we check the specific error message)
resource "null_resource" "eks_nodegroup_service_linked_role" {
  count = var.create_eks_nodegroup_service_linked_role ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      output=$(aws iam create-service-linked-role --aws-service-name eks-nodegroup.amazonaws.com 2>&1) || {
        if echo "$output" | grep -q "has been taken in this account"; then
          echo "Service-linked role already exists, continuing..."
          exit 0
        else
          echo "$output" >&2
          exit 1
        fi
      }
    EOT
  }
}
