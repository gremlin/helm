# Charts are derived, not listed, so a third chart is picked up without
# anyone remembering to edit this file.
CHARTS := $(patsubst %/Chart.yaml,%,$(wildcard */Chart.yaml))

export HELM_DOCS_VERSION     := 1.14.2
export SCHEMA_PLUGIN_VERSION := v2.2.0
export PRE_COMMIT_VERSION    := 4.6.2

.PHONY: setup lint schema docs test check

## Install the pinned toolchain and register the pre-commit hooks. Idempotent.
setup:
	@hooks/setup.sh

## helm lint every chart, with defaults and with its ci/linting overrides.
lint:
	@hooks/helm-lint.sh

## Regenerate every chart's values.schema.json from its .schema.yaml.
schema:
	@hooks/helm-schema.sh

## Regenerate every chart's README.md from its README.md.gotmpl + values.yaml.
docs:
	@hooks/helm-docs.sh

## Run the helm unittest suites (same suites .github/workflows/unittest.yml runs).
test:
	@set -e; $(foreach c,$(CHARTS),helm unittest $(c);)

## schema, docs and lint all read and (re)write the same chart directories;
## running them concurrently under `make -j` would race on that shared state.
.NOTPARALLEL: check

## Everything a PR will be checked for, in the order CI runs it.
check: schema docs lint
	@git diff --exit-code -- $(addsuffix /values.schema.json,$(CHARTS)) $(addsuffix /README.md,$(CHARTS))
