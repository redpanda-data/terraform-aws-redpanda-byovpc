resource "random_string" "unique_id" {
  length  = 10
  special = false
  upper   = false
}

data "aws_caller_identity" "current" {}

locals {
  aws_account_id = (
    var.aws_account_id != ""
    ? var.aws_account_id
    : data.aws_caller_identity.current.account_id
  )
}
