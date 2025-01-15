terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.6.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.2"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = var.default_tags
  }
  ignore_tags {
    key_prefixes = var.ignore_tags
  }
    access_key = var.aws_access_key
    secret_key = var.aws_secret_key
}
