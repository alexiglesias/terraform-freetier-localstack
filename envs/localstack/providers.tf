# Every API call goes to LocalStack on localhost:4566, never to real AWS.
# The dummy credentials stop the provider from picking up your real
# ~/.aws/credentials by accident.

provider "aws" {
  region     = var.aws_region
  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    ec2 = "http://localhost:4566"
    iam = "http://localhost:4566"
    sts = "http://localhost:4566"
  }

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Env       = "localstack"
    }
  }
}
