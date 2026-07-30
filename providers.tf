# A single provider block that targets either real AWS or a local LocalStack
# container, switched by var.use_localstack. This is what lets the exact same
# .tf files serve both the Free Tier path and the always-free local path.

provider "aws" {
  region = var.aws_region

  # LocalStack doesn't check real credentials, but the AWS provider still
  # wants *something* in these fields, or it will try to load your real
  # ~/.aws/credentials and, on LocalStack, fail or silently target real AWS.
  access_key = var.use_localstack ? "test" : null
  secret_key = var.use_localstack ? "test" : null

  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack

  # LocalStack's S3 implementation expects path-style addressing
  # (http://localhost:4566/bucket-name/key) rather than the virtual-hosted
  # style (http://bucket-name.s3.amazonaws.com/key) real AWS uses.
  s3_use_path_style = var.use_localstack

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      ec2        = "http://localhost:4566"
      s3         = "http://localhost:4566"
      rds        = "http://localhost:4566"
      elbv2      = "http://localhost:4566"
      iam        = "http://localhost:4566"
      sts        = "http://localhost:4566"
      dynamodb   = "http://localhost:4566"
      cloudwatch = "http://localhost:4566"
      budgets    = "http://localhost:4566"
    }
  }

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Env       = var.use_localstack ? "localstack" : "aws-freetier"
    }
  }
}
