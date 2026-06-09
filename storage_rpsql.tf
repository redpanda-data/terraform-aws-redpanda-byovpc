# S3 bucket used for Redpanda SQL cloud storage (module-managed in BYOVPC mode).
# The ARN is exposed via the rpsql_cloud_storage_bucket_arn output so it can be
# wired into the cluster's rpsql_cloud_storage_bucket customer-managed resource.
resource "aws_s3_bucket" "rpsql" {
  count         = var.enable_redpanda_sql ? 1 : 0
  bucket_prefix = "redpanda-rpsql-cloud-storage-"
  force_destroy = var.force_destroy_cloud_storage
  tags          = var.default_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "rpsql" {
  count  = var.enable_redpanda_sql ? 1 : 0
  bucket = aws_s3_bucket.rpsql[0].bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "rpsql" {
  count  = var.enable_redpanda_sql ? 1 : 0
  bucket = aws_s3_bucket.rpsql[0].id
  versioning_configuration {
    # versioning on the cloud storage bucket is not recommended
    status = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "rpsql" {
  count                   = var.enable_redpanda_sql ? 1 : 0
  bucket                  = aws_s3_bucket.rpsql[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "rpsql" {
  count  = var.enable_redpanda_sql ? 1 : 0
  bucket = aws_s3_bucket.rpsql[0].id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
