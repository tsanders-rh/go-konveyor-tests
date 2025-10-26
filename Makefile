VENDOR_DIR ?= /tmp/konveyor-vendor
ARCH ?= amd64
JUNIT_REPORT_DIR ?= /tmp/junit-report

#
# Help / Documentation
#

.PHONY: help
help: ## Show this help message
	@echo "Konveyor Test Suite - Available targets:"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Environment Variables:"
	@echo "  HUB_BASE_URL       - Konveyor Hub URL (required for tests)"
	@echo "  DEBUG=1            - Enable debug output"
	@echo "  KEEP=1             - Keep test data after execution"
	@echo "  PARALLEL=1         - Run tests in parallel"
	@echo ""
	@echo "Example: DEBUG=1 make test-tier0"

#
# Environment Setup and Validation
#

.PHONY: validate-env
validate-env: ## Validate Go environment and dependencies
	@echo "Validating Go installation..."
	@command -v go >/dev/null 2>&1 || { echo "Error: Go is not installed. Please install Go 1.21+"; exit 1; }
	@echo "Go version: $$(go version)"
	@echo "Checking Go module dependencies..."
	@go mod download
	@echo "✓ Environment validation passed"

.PHONY: check-hub-url
check-hub-url: ## Check if HUB_BASE_URL is set and accessible
	@if [ -z "$$HUB_BASE_URL" ]; then \
		echo "Error: HUB_BASE_URL is not set."; \
		echo ""; \
		echo "For Minikube:  export HUB_BASE_URL=\"http://\$$(minikube ip)/hub\""; \
		echo "For OpenShift: export HUB_BASE_URL=\"https://tackle-konveyor-tackle.apps.your-cluster.example.com/hub\""; \
		echo ""; \
		exit 1; \
	fi
	@echo "HUB_BASE_URL is set to: $$HUB_BASE_URL"
	@echo "Testing connectivity..."
	@curl -f -k -s -o /dev/null "$$HUB_BASE_URL" || { echo "Warning: Cannot connect to $$HUB_BASE_URL"; exit 1; }
	@echo "✓ Hub is accessible"

.PHONY: setup-check
setup-check: ## Verify Konveyor installation is ready
	@echo "Checking Kubernetes connection..."
	@kubectl cluster-info >/dev/null 2>&1 || { echo "Error: Cannot connect to Kubernetes cluster"; exit 1; }
	@echo "✓ Connected to cluster: $$(kubectl config current-context)"
	@echo ""
	@echo "Checking Konveyor namespace..."
	@kubectl get namespace konveyor-tackle >/dev/null 2>&1 || { echo "Error: konveyor-tackle namespace not found"; exit 1; }
	@echo "✓ Konveyor namespace exists"
	@echo ""
	@echo "Checking Konveyor pods..."
	@kubectl get pods -n konveyor-tackle
	@echo ""
	@echo "Checking Hub deployment..."
	@kubectl get deployment -n konveyor-tackle tackle-hub >/dev/null 2>&1 || { echo "Warning: tackle-hub deployment not found"; }
	@echo "✓ Setup check complete"

# Setup local minikube with Konveyor/Tackle
# Downloads installation scripts from konveyor/operator repository
setup: ## Setup Minikube with Konveyor (for local development)
	@echo "Setting up Minikube with Konveyor..."
	@echo "This will download scripts from https://github.com/konveyor/operator"
	@command -v minikube >/dev/null 2>&1 || { echo "Error: minikube is not installed"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl is not installed"; exit 1; }
	mkdir -p ${VENDOR_DIR}
	@echo "Downloading start-minikube.sh..."
	curl -fsSL https://raw.githubusercontent.com/konveyor/operator/main/hack/start-minikube.sh -o ${VENDOR_DIR}/start-minikube.sh
	chmod +x ${VENDOR_DIR}/start-minikube.sh
	@echo "Downloading install-tackle.sh..."
	curl -fsSL https://raw.githubusercontent.com/konveyor/operator/main/hack/install-tackle.sh -o ${VENDOR_DIR}/install-tackle.sh
	chmod +x ${VENDOR_DIR}/install-tackle.sh
	@echo "Starting Minikube..."
	${VENDOR_DIR}/start-minikube.sh
	@echo "Installing Konveyor/Tackle..."
	${VENDOR_DIR}/install-tackle.sh
	@echo ""
	@echo "✓ Setup complete!"
	@echo ""
	@echo "Set your HUB_BASE_URL:"
	@echo "  export HUB_BASE_URL=\"http://\$$(minikube ip)/hub\""
	@echo ""
	@echo "Verify setup:"
	@echo "  make setup-check"

# Clean local minikube with tackle
clean: ## Delete Minikube cluster
	@echo "Deleting Minikube cluster..."
	minikube delete || true
	@echo "✓ Cleanup complete"

# Update Hub dependency with latest binding and api.
update-hub: ## Update tackle2-hub dependency to latest
	go get -u github.com/konveyor/tackle2-hub@main

#
# Test tiers
#
# Tests are organized by criticality. TIER0 must pass, TIER1 should pass,
# TIER2+ are nice-to-have. Set HUB_BASE_URL before running tests.
#

.PHONY: test-tier0
test-tier0: ## Run TIER0 tests (core functionality, must pass)
	@echo "Running TIER0 tests (core functionality)..."
	@$(MAKE) check-hub-url
	$(MAKE) test-analysis

.PHONY: test-tier1
test-tier1: ## Run TIER1 tests (common features, should work)
	@echo "Running TIER1 tests (common features)..."
	@$(MAKE) check-hub-url
	$(MAKE) test-metrics
	TIER1=1 $(MAKE) test-analysis

.PHONY: test-tier2
test-tier2: ## Run TIER2 tests (advanced features)
	@echo "Running TIER2 tests (advanced features)..."
	@$(MAKE) check-hub-url
	TIER2=1 $(MAKE) test-analysis

.PHONY: test-tier3
test-tier3: ## Run TIER3 tests (requires credentials)
	@echo "Running TIER3 tests (requires credentials)..."
	@$(MAKE) check-hub-url
	$(MAKE) test-jira
	$(MAKE) test-migrationwave
	TIER3=1 $(MAKE) test-analysis

.PHONY: test-quick
test-quick: ## Quick validation test (subset of TIER0)
	@echo "Running quick validation test..."
	@$(MAKE) check-hub-url
	@echo "Running basic analysis test..."
	go test -v -count=1 -timeout 30m ./analysis -run TestApplicationAnalysis/tackle-testapp

#
# Feature tests
#

.PHONY: test-analysis
test-analysis: ## Run application analysis tests
	go install github.com/jstemmer/go-junit-report/v2@latest
	mkdir -pv ${JUNIT_REPORT_DIR}
	go test -count=1 -p=1 -timeout 7200s -v ./analysis/... 2>&1 | \
	go-junit-report -iocopy -set-exit-code -out ${JUNIT_REPORT_DIR}/analysis-report_$$(date +%s).xml

.PHONY: test-metrics
test-metrics: ## Run metrics collection tests
	cd e2e/metrics/ && ginkgo -v --junit-report=metrics-report.xml --output-dir=${JUNIT_REPORT_DIR}

.PHONY: test-jira
test-jira: ## Run Jira integration tests (requires credentials)
	cd e2e/jiraintegration/ && ginkgo -v --junit-report=jiraintegration-report.xml --output-dir=${JUNIT_REPORT_DIR}

.PHONY: test-migrationwave
test-migrationwave: ## Run migration wave tests
	cd e2e/migrationwave/ && ginkgo -v --junit-report=migrationwave-report.xml --output-dir=${JUNIT_REPORT_DIR}

.PHONY: test-hub-api
test-hub-api: ## Run upstream Hub API tests
	./hub-api/run-tests.sh ${HUB_TESTS_REF}

.PHONY: test-all
test-all: test-tier0 test-tier1 test-tier2 test-tier3 ## Run all test tiers

#
# Reporting
#

.PHONY: merge-report
merge-report: ## Merge JUnit reports into single file
	go install github.com/nezorflame/junit-merger@latest
	cd ${JUNIT_REPORT_DIR} && rm -f merged.xml && junit-merger -o merged.xml *

.PHONY: clean-report-dir
clean-report-dir: ## Clean JUnit report directory
	rm -f ${JUNIT_REPORT_DIR}/*
