# tflint: catches mistakes `terraform validate` can't (invalid instance
# types, deprecated syntax, unused variables, missing descriptions...).
#   tflint --init && tflint --recursive

config {
  # Also lint the local modules when linting envs/* and bootstrap/.
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.49.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
