# AWS Glue Data Catalog permissions for the Iceberg REST catalog integration
# (cluster configuration iceberg_catalog_type=rest pointed at the regional
# Glue endpoint with aws_sigv4 authentication and credentials_source=sts).
#
# The brokers sign Glue calls with the agent-created IRSA role
# redpanda-cloud-storage-manager-<cluster-id>, and the Redpanda SQL engine
# with redpanda-<cluster-id>-redpanda-oxla-cluster. Both exist only after
# cluster creation, so this module can only provide the policy (and allow the
# actions in the agent permissions boundary that caps those roles); attach
# glue_iceberg_policy_arn to them from the workspace that creates the cluster.
# See "AWS Glue Iceberg catalog" in the README.

data "aws_iam_policy_document" "glue_iceberg" {
  count = var.enable_glue_iceberg_catalog ? 1 : 0

  statement {
    sid    = "RedpandaIcebergGlue"
    effect = "Allow"
    actions = [
      "glue:GetCatalog",
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:CreateDatabase",
      "glue:GetTable",
      "glue:GetTables",
      "glue:CreateTable",
      "glue:UpdateTable",
      "glue:DeleteTable",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "glue_iceberg" {
  count       = var.enable_glue_iceberg_catalog ? 1 : 0
  name_prefix = "${var.common_prefix}-glue-iceberg-"
  policy      = data.aws_iam_policy_document.glue_iceberg[0].json
  tags        = var.default_tags
}

resource "aws_iam_role_policy_attachment" "glue_iceberg_redpanda_node_group" {
  count      = var.enable_glue_iceberg_catalog ? 1 : 0
  role       = aws_iam_role.redpanda_node_group.name
  policy_arn = aws_iam_policy.glue_iceberg[0].arn
}

resource "aws_iam_role_policy_attachment" "glue_iceberg_rpsql_node_group" {
  count      = var.enable_glue_iceberg_catalog && var.enable_redpanda_sql ? 1 : 0
  role       = aws_iam_role.rpsql_node_group[0].name
  policy_arn = aws_iam_policy.glue_iceberg[0].arn
}
