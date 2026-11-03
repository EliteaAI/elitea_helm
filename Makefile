.PHONY: lint template bump help

CHART=charts
NS ?= test
KUBE ?= 1.35
VALS ?= values.yaml
OUT ?= build/render.yaml
RELEASE ?= elitea
# dummy secrets so the default values.yaml can be linted/templated
CI_VALS = $(if $(filter values.yaml,$(VALS)),-f "$(CHART)/ci/test-values.yaml")


help: ## Show this help
	@echo "Available targets:"
	@echo "  lint          - Lint the helm chart 'make lint NS=test"
	@echo "  template      - Template the helm chart"
	@echo "  bump          - Bump version + CHANGELOG + tag from commits (commitizen)"
	@echo "  help          - Show this help message"

lint:
	@echo "Starting linting..."
	@helm lint "$(CHART)" -f "$(CHART)/$(VALS)" $(CI_VALS) --strict

template: ## Template the helm chart
	@echo "Starting templating..."
	@mkdir -p "build/"
	@helm template --debug "$(RELEASE)" "$(CHART)" -n "$(NS)" -f "$(CHART)/$(VALS)" $(CI_VALS) --kube-version "$(KUBE)" > "$(OUT)"

bump: ## Bump chart version from conventional commits, update CHANGELOG, create tag (then: git push --follow-tags)
	@uv run cz bump
