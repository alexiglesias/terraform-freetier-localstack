# Front door for the repo: `make` (or `make help`) lists everything.
#
# ENV defaults to localstack, so nothing ever touches real AWS by accident:
#   make apply               -> LocalStack (free)
#   make plan ENV=aws        -> real AWS, read-only (free)
#   make apply ENV=aws       -> real AWS, costs money while it runs

ENV ?= localstack
TF  := scripts/tf.sh
ROOTS := bootstrap envs/aws envs/localstack

.DEFAULT_GOAL := help
.PHONY: help up down plan apply destroy output fmt check lint security test ci cleanup

help: ## Show this help
	@echo "Usage: make <target> [ENV=localstack|aws]   (default ENV=$(ENV))"
	@echo
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

up: ## Start LocalStack (docker compose)
	@scripts/localstack-up.sh

down: ## Stop LocalStack and throw away its state
	@docker compose down

plan: ## Show what would change - changes nothing, free even on AWS
	@$(TF) $(ENV) plan

apply: ## Plan, confirm, apply exactly that plan
	@$(TF) $(ENV) apply

destroy: ## Plan destroy, confirm, apply exactly that plan
	@$(TF) $(ENV) destroy

output: ## Show the environment's outputs
	@$(TF) $(ENV) output

fmt: ## Format all Terraform files
	terraform fmt -recursive

check: ## fmt check + validate every root (offline, no cloud access)
	terraform fmt -check -recursive
	@for d in $(ROOTS); do \
	  echo "== $$d"; \
	  terraform -chdir=$$d init -backend=false -input=false >/dev/null && \
	  terraform -chdir=$$d validate || exit 1; \
	done

lint: ## tflint, incl. AWS rules, on every root and module
	tflint --init
	tflint --recursive

security: ## checkov security + leaked-secrets scan
	checkov --config-file .checkov.yaml

test: ## Unit tests for every module (mock providers - offline, free)
	@for m in modules/*/; do \
	  echo "== $$m"; \
	  terraform -chdir=$$m init -backend=false -input=false >/dev/null && \
	  terraform -chdir=$$m test || exit 1; \
	done

ci: check lint security test ## Everything CI runs, in order

cleanup: ## EMERGENCY: remove everything billable this project left in AWS
	@scripts/cleanup-aws.sh
