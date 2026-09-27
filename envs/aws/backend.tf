# Remote state in S3 (created by bootstrap/). This is a *partial* backend
# config: the bucket and region live in backend.hcl, which bootstrap/
# generates and git ignores, so your account ID never lands in the repo.
#
#   terraform -chdir=envs/aws init -backend-config=backend.hcl
#
# use_lockfile = S3-native state locking (Terraform >= 1.10). It replaces
# the old DynamoDB lock table, which is deprecated.

terraform {
  backend "s3" {
    key          = "terraform-freetier-localstack/aws/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
