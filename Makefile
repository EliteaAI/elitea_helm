.PHONY: lint template bump tag help

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
	@echo "  bump          - Bump version + CHANGELOG from commits (commitizen), no commit/tag: open a release PR"
	@echo "  tag           - Tag the current commit with the chart version (after the release PR is merged)"
	@echo "  help          - Show this help message"

lint:
	@echo "Starting linting..."
	@helm lint "$(CHART)" -f "$(CHART)/$(VALS)" $(CI_VALS) --strict

template: ## Template the helm chart
	@echo "Starting templating..."
	@mkdir -p "build/"
	@helm template --debug "$(RELEASE)" "$(CHART)" -n "$(NS)" -f "$(CHART)/$(VALS)" $(CI_VALS) --kube-version "$(KUBE)" > "$(OUT)"

bump: ## Bump chart version + CHANGELOG from conventional commits (files only: commit them on a release branch, open a PR)
	@uv run cz bump --files-only

tag: ## Tag the current commit v<chart version>; then: git push origin v<version> (triggers the release workflow)
	@v=$$(sed -n 's/^version: *//p' "$(CHART)/Chart.yaml" | tr -d '"'); git tag "v$$v" && echo "created v$$v, now: git push origin v$$v"
