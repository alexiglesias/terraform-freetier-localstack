terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # No backend block: the bootstrap creates the state bucket, so it can't
  # store its own state there before it exists. Its state stays local
  # (bootstrap/terraform.tfstate, gitignored). Losing it is not a disaster:
  # the bucket and budget can be re-imported with `terraform import`.
}
