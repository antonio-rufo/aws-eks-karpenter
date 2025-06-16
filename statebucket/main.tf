###############################################################################
# Provider
###############################################################################
provider "aws" {
    region              = var.region
    allowed_account_ids = [var.aws_account_id]
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

###############################################################################
# S3 Bucket
###############################################################################
resource "aws_s3_bucket" "state" {
    bucket        = "${var.aws_account_id}-bucket-state-file-karpenter"
    force_destroy = true

}
