SHELL:=/bin/bash -o pipefail -O globstar
.SHELLFLAGS = -ec
.PHONY: build dist
.DEFAULT_GOAL := list
make := make --no-print-directory

list:
	@grep '^[^#[:space:]].*:' Makefile


guard-%:
	@if [[ "${${*}}" == "" ]]; then \
		echo "env var: $* not set"; \
		exit 1; \
	fi

########################################################################################################################
##
## Makefile for this project things
##
########################################################################################################################
pwd := ${PWD}
dirname := $(notdir $(patsubst %/,%,$(CURDIR)))

tf-lint:
	tflint --chdir=modules/aws-backup-source --config "$(pwd)/.tflint.hcl"
	tflint --chdir=modules/aws-backup-destination --config "$(pwd)/.tflint.hcl"
	tflint --chdir=examples/source --config "$(pwd)/.tflint.hcl"
	tflint --chdir=examples/destination --config "$(pwd)/.tflint.hcl"

tf-format-check:
	terraform fmt -check -recursive

tf-format:
	terraform fmt --recursive

tf-trivy:
	trivy conf --exit-code 1 ./ --skip-dirs "**/.terraform"

shellcheck:
	@docker run --rm -i -v ${PWD}:/mnt:ro koalaman/shellcheck -f gcc -e SC1090,SC1091 `find . \( -path "*/.venv/*" -prune -o -path "*/build/*" -prune -o -path "*/dist/*" -prune  -o -path "*/.tox/*" -prune \) -o -type f -name '*.sh' -print`

lint: tf-lint tf-trivy shellcheck

check-secrets:
	scripts/check-secrets.sh

check-secrets-all:
	scripts/check-secrets.sh unstaged

.env:
	echo "LOCALSTACK_PORT=$$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1])')" > .env
