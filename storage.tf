# S3 bucket used for tiered storage
resource "aws_s3_bucket" "redpanda_cloud_storage" {
  bucket_prefix = "redpanda-cloud-storage-"
  force_destroy = var.force_destroy_cloud_storage
  tags          = var.default_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "redpanda_cloud_storage" {
  bucket = aws_s3_bucket.redpanda_cloud_storage.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "redpanda_cloud_storage" {
  bucket = aws_s3_bucket.redpanda_cloud_storage.id
  versioning_configuration {
    # versioning on the cloud storage bucket is not recommended
    status = "Disabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "redpanda_cloud_storage" {
  bucket = aws_s3_bucket.redpanda_cloud_storage.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# S3 bucket used for terraform state and other data plane configuration
resource "aws_s3_bucket" "management" {
  bucket_prefix = "rp-${local.aws_account_id}-${var.region}-mgmt-"
  force_destroy = var.force_destroy_management_bucket
  tags          = var.default_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "management" {
  bucket = aws_s3_bucket.management.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "management" {
  bucket = aws_s3_bucket.management.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "management" {
  bucket = aws_s3_bucket.management.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Terraform state locking uses S3, so the DynamoDB table is no longer used. This drops an existing
# table from the Terraform state without deleting it, because older agents can still use it.
removed {
  from = aws_dynamodb_table.terraform_locks

  lifecycle {
    destroy = false
  }
}
