data "aws_s3_bucket" "source_bucket" {
  for_each = var.source_cluster_bucket_names
  bucket   = each.value
}

data "aws_iam_policy_document" "read_replicas" {
  dynamic "statement" {
    for_each = data.aws_s3_bucket.source_bucket
    content {
      principals {
        type = "AWS"
        identifiers = [
          "arn:aws:iam::${local.aws_account_id}:role/redpanda-cloud-storage-manager-${var.reader_cluster_id}"
        ]
      }

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

resource "aws_s3_bucket_policy" "read_replicas" {
  for_each = data.aws_s3_bucket.source_bucket
  bucket   = each.value.id
  policy   = data.aws_iam_policy_document.read_replicas.json
}
