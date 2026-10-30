# AWS Glue Data Catalog permissions for the Iceberg REST catalog integration
# (cluster configuration iceberg_catalog_type=rest pointed at the regional
# Glue endpoint with aws_sigv4 authentication and credentials_source=sts).
#
# The only Glue callers are two agent-created IRSA roles: the brokers sign
# with redpanda-cloud-storage-manager-<cluster-id>, and the Redpanda SQL
# engine with redpanda-<cluster-id>-redpanda-oxla-cluster. cloudv2 never
# routes Glue (or S3) through the node group instance profiles, so the node
# group roles need no Glue permissions. Both IRSA roles exist only after
# cluster creation, so this module can only provide the policies (and allow the
# actions in the agent permissions boundary that caps those roles); attach
# glue_iceberg_policy_arn to the broker role and
# glue_iceberg_read_only_policy_arn to the Redpanda SQL role from the workspace
# that creates the cluster. See "AWS Glue Iceberg catalog" in the README.

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
    resources = [
      "arn:aws:glue:${var.region}:${local.aws_account_id}:catalog",
      "arn:aws:glue:${var.region}:${local.aws_account_id}:database/*",
      "arn:aws:glue:${var.region}:${local.aws_account_id}:table/*/*",
    ]
  }
}

resource "aws_iam_policy" "glue_iceberg" {
  count       = var.enable_glue_iceberg_catalog ? 1 : 0
  name_prefix = "${var.common_prefix}-glue-iceberg-"
  policy      = data.aws_iam_policy_document.glue_iceberg[0].json
  tags        = local.module_iam_tags
}

# Read-only on the topic-data databases only: Redpanda SQL never writes topic data.
data "aws_iam_policy_document" "glue_iceberg_read_only" {
  count = var.enable_glue_iceberg_catalog && var.enable_redpanda_sql ? 1 : 0

  statement {
    sid    = "RedpandaSQLIcebergGlueReadOnly"
    effect = "Allow"
    actions = [
      "glue:GetCatalog",
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables",
    ]
    resources = concat(
      ["arn:aws:glue:${var.region}:${local.aws_account_id}:catalog"],
      [for db in var.glue_iceberg_namespaces : "arn:aws:glue:${var.region}:${local.aws_account_id}:database/${db}"],
      [for db in var.glue_iceberg_namespaces : "arn:aws:glue:${var.region}:${local.aws_account_id}:table/${db}/*"],
    )
  }
}

resource "aws_iam_policy" "glue_iceberg_read_only" {
  count       = var.enable_glue_iceberg_catalog && var.enable_redpanda_sql ? 1 : 0
  name_prefix = "${var.common_prefix}-glue-iceberg-ro-"
  policy      = data.aws_iam_policy_document.glue_iceberg_read_only[0].json
  tags        = var.default_tags
}
