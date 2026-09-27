provider "aws" {
  region = var.aws_region

  # Refuse to run against any other account - e.g. if AWS_PROFILE isn't set
  # and the CLI falls back to credentials from another project.
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Env       = "bootstrap"
    }
  }
}
