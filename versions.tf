terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # See backend.tf.example for the S3 + DynamoDB remote backend.
  # Left out of this file on purpose: the backend bucket/table have to
  # exist before `terraform init` can use them (see scripts/bootstrap-backend.sh),
  # and LocalStack runs are simplest with local state anyway.
}
