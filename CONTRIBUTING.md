# Contributing to go-konveyor-tests

Thank you for your interest in contributing to Konveyor's test suite! This guide will help you get started quickly.

## Quick Start

### Prerequisites

- Go 1.21 or later
- Kubernetes cluster (Minikube, kind, or OpenShift)
- `kubectl` configured with access to your cluster
- Git

### 1. Clone and Setup

```bash
git clone https://github.com/konveyor/go-konveyor-tests
cd go-konveyor-tests
```

### 2. Local Environment Setup

#### Option A: Minikube (Recommended for development)

```bash
# Start Minikube and install Konveyor
make setup

# Set the HUB_BASE_URL
export HUB_BASE_URL="http://$(minikube ip)/hub"
```

**Note:** The `make setup` target downloads installation scripts from the [konveyor/operator](https://github.com/konveyor/operator) repository. If you encounter issues, you can manually run:

```bash
# Download and run scripts manually
mkdir -p /tmp/konveyor-vendor
curl https://raw.githubusercontent.com/konveyor/operator/main/hack/start-minikube.sh -Lo /tmp/konveyor-vendor/start-minikube.sh
chmod +x /tmp/konveyor-vendor/start-minikube.sh
/tmp/konveyor-vendor/start-minikube.sh

curl https://raw.githubusercontent.com/konveyor/operator/main/hack/install-tackle.sh -Lo /tmp/konveyor-vendor/install-tackle.sh
chmod +x /tmp/konveyor-vendor/install-tackle.sh
/tmp/konveyor-vendor/install-tackle.sh
```

#### Option B: Existing OpenShift Cluster

If you have an existing OpenShift cluster with Konveyor installed:

```bash
# Point to your cluster
export KUBECONFIG=/path/to/your/kubeconfig

# Set the Hub URL (replace with your actual route)
export HUB_BASE_URL="https://tackle-konveyor-tackle.apps.your-cluster.example.com/hub"
```

**HTTPS Certificate Note:** For HTTPS endpoints, you may need to import certificate chains. See the [Hub API test README](https://github.com/konveyor/tackle2-hub/tree/main/test#https) for details.

#### Option C: Quick Validation (No local cluster)

You can run the setup validation target to check your Go environment without a cluster:

```bash
make validate-env
```

### 3. Configure Test Environment

Copy and edit the configuration file:

```bash
cp go-konveyor-tests.config go-konveyor-tests.config.local
```

Edit `go-konveyor-tests.config.local` with your settings:

```bash
export HUB_BASE_URL="http://$(minikube ip)/hub"
export HUB_USERNAME="admin"
export HUB_PASSWORD="Passw0rd!"  # Default Konveyor password
export KUBECONFIG="~/.kube/config"
```

Then source it:

```bash
source go-konveyor-tests.config.local
```

**Tip:** Add `*.local` to your `.gitignore` to avoid accidentally committing credentials.

### 4. Run Tests Locally

Before submitting a PR, run the appropriate tier tests:

```bash
# Run core tests (TIER0) - These MUST pass for your PR
make test-tier0

# Run with debug output to see detailed analysis results
DEBUG=1 make test-tier0

# Keep test data for debugging (doesn't clean up applications/tasks)
KEEP=1 make test-tier0

# Run specific test file directly
go test -v -count=1 -timeout 30m ./analysis -run TestApplicationAnalysis
```

## Understanding Test Tiers

Tests are organized into tiers based on criticality and use case complexity:

| Tier | Description | PR Requirement | Example Tests |
|------|-------------|----------------|---------------|
| **TIER0** | Core functionality - must never fail | **Required to pass** | Basic app analysis, create/delete applications |
| **TIER1** | Common features - expected to work | **Should pass** | Real-world app analysis, metrics collection |
| **TIER2** | Advanced features and edge cases | Nice to have | Complex analysis scenarios, advanced rules |
| **TIER3** | Tests requiring credentials/private resources | Not run on PRs | Jira integration, migration waves |

### What Needs to Pass for My PR?

- **TIER0 must pass** - Your PR will not be merged if TIER0 fails
- **TIER1 should pass** - Failures require investigation and justification
- **TIER2 nice to have** - Failures are acceptable if not related to your changes
- **TIER3 runs separately** - Executed via Jenkins with credentials, not on PRs

### CI Workflow on Pull Requests

When you open a PR against `main`, the CI automatically runs:

1. **TIER0, TIER1, and TIER2** - All run in parallel
2. Each tier uses the latest operator bundle: `quay.io/konveyor/tackle2-operator-bundle:latest`
3. Tests run with `DEBUG=1` enabled
4. Results appear as GitHub Actions checks on your PR

**Common CI Issues:**

- **Timeout:** Tests have a 2-hour timeout. If exceeded, check for hung analyses
- **Flaky Tests:** Analysis tests can be sensitive to timing. Re-run failed checks once before investigating
- **External Dependencies:** Tests clone the [konveyor/ci](https://github.com/konveyor/ci) repository for test case configurations

## Adding New Tests

### Test Structure

```
go-konveyor-tests/
├── analysis/              # Application analysis tests (most common)
│   ├── analysis_test.go   # Main test runner
│   ├── test_cases.go      # Test case registry
│   └── tc_*.go            # Individual test case definitions
├── e2e/                   # End-to-end feature tests
│   ├── jiraintegration/   # Jira integration tests
│   ├── metrics/           # Metrics tests
│   └── migrationwave/     # Migration wave tests
└── utils/                 # Shared test utilities
```

### Adding an Analysis Test Case

Analysis tests follow a hybrid Go + YAML configuration approach:

1. **Create a new test case file** (e.g., `analysis/tc_mynewapp.go`):

```go
package analysis

var MyNewApp = TC{
    Name:        "MyNewApp",
    Application: api.Application{
        Name:        "my-new-app",
        Description: "Description of the app",
        Repository: &api.Repository{
            Kind:   "git",
            URL:    "https://github.com/example/my-new-app",
            Branch: "main",
        },
    },
    Task: Analyze{
        Tiers: []int{0}, // TIER0 for core functionality
        Sources: []string{
            "java",
        },
        Targets: []string{
            "cloud-readiness",
        },
    },
    Analysis: api.Analysis{
        Effort: 5, // Expected story points
        Issues: []api.Issue{
            {
                Category: "mandatory",
                RuleSet:  "my-ruleset",
                Rule:     "my-rule-001",
            },
        },
        Dependencies: []api.TechDependency{
            {Name: "junit", Version: "4.12"},
        },
    },
}
```

2. **Register the test case** in `analysis/test_cases.go`:

```go
var TestCases = []TC{
    // ... existing cases
    MyNewApp,
}
```

3. **Run your test:**

```bash
DEBUG=1 go test -v ./analysis -run TestApplicationAnalysis
```

### Alternative: YAML-only Configuration

You can also define test cases purely in YAML by contributing to the [konveyor/ci](https://github.com/konveyor/ci) repository's `shared_tests/test_cases.yml` file. This is useful for:

- Sharing test cases across multiple test suites
- Rapid iteration without Go code changes
- Centralized test case management

### Adding E2E Tests

For feature tests outside of analysis (e.g., new Konveyor features):

1. Create a new directory under `e2e/`
2. Use Ginkgo for test structure (see `e2e/metrics/` for examples)
3. Add a README.md explaining the feature and any required configuration
4. Add a new target to the Makefile
5. Add the target to the appropriate tier in the Makefile

## Pull Request Process

### Before Submitting

- [ ] Run `make test-tier0` locally and ensure it passes
- [ ] Run `make test-tier1` if your changes affect common use cases
- [ ] Add test cases for new features or bug fixes
- [ ] Update relevant README files if adding new test types
- [ ] Ensure your commits are clear and well-described

### Submitting Your PR

1. **Fork the repository** and create a feature branch from `main`
2. **Make your changes** with clear, atomic commits
3. **Push to your fork** and create a Pull Request
4. **Wait for CI checks** - All three tier workflows will run
5. **Address review feedback** - Maintainers will review and may request changes

### PR Checklist

Your PR will be reviewed for:

- ✅ **TIER0 passes** - Non-negotiable requirement
- ✅ **Test coverage** - New features include test cases
- ✅ **Code quality** - Follows existing patterns and Go conventions
- ✅ **Documentation** - README updates for new test types
- ✅ **CI green** - All checks pass

### After Merge

- Your changes will be included in nightly test runs
- If merged to `main`, automatic cherry-pick to release branches may occur (via `pr-closed.yaml`)
- Nightly runs execute at 1:14 AM and 1:14 PM UTC

## Development Tips

### Debugging Failed Tests

```bash
# Run with maximum verbosity
DEBUG=1 go test -v -count=1 ./analysis -run TestApplicationAnalysis

# Keep applications and tasks for inspection
KEEP=1 DEBUG=1 go test -v ./analysis

# Check Hub logs (Minikube)
kubectl logs -n konveyor-tackle -l app=tackle-hub

# Check analysis task logs
kubectl logs -n konveyor-tackle -l app=tackle-analyzer
```

### Working with Test Data

```bash
# Clean up test data manually
kubectl delete applications -n konveyor-tackle --all
kubectl delete tasks -n konveyor-tackle --all

# Reset Minikube completely
make clean
make setup
```

### Using Custom CI Repository

For testing changes to test case configurations:

```bash
export CI_REPO_URL="https://github.com/your-fork/ci"
export CI_REPO_BRANCH="my-test-branch"
make test-tier0
```

### Parallel Test Execution

```bash
# Run tests in parallel (faster, but harder to debug)
PARALLEL=1 make test-tier0
```

### Understanding Test Timing

- **Analysis tests** can take 30+ minutes for complex applications
- **Timeout is 2 hours** for the entire test suite
- Use **TIER0 for quick validation** (5-10 minutes typically)
- **TIER1/TIER2** include larger applications and take longer

## Troubleshooting

### "HUB_BASE_URL not set"

```bash
# For Minikube
export HUB_BASE_URL="http://$(minikube ip)/hub"

# Verify it's accessible
curl -k $HUB_BASE_URL
```

### "Failed to create application"

- Check that Konveyor is running: `kubectl get pods -n konveyor-tackle`
- Verify Hub is accessible: `curl -k $HUB_BASE_URL/applications`
- Check authentication: Ensure `HUB_USERNAME` and `HUB_PASSWORD` are correct

### "Analysis task timeout"

- Increase test timeout: `go test -timeout 60m ...`
- Check analyzer pod logs: `kubectl logs -n konveyor-tackle -l app=tackle-analyzer`
- Verify application source is accessible from the cluster

### "CI repository clone failed"

- Check network connectivity
- Verify `CI_REPO_URL` and `CI_REPO_BRANCH` are correct
- Try running with default values (remove custom CI env vars)

### Tests Pass Locally but Fail in CI

- CI uses the latest operator bundle, which may differ from your local version
- CI runs with `DEBUG=1` by default
- Check the GitHub Actions logs for specific error messages
- Timing differences: CI environment may be slower/faster than local

## Getting Help

- **GitHub Issues:** [Report bugs or ask questions](https://github.com/konveyor/go-konveyor-tests/issues)
- **Discussions:** [Konveyor community discussions](https://github.com/konveyor/community/discussions)
- **Slack:** Join the [Konveyor Slack workspace](https://kubernetes.slack.com/archives/CR85S82A2)
- **Code of Conduct:** Please follow the [Konveyor Code of Conduct](https://github.com/konveyor/community/blob/main/CODE_OF_CONDUCT.md)

## Additional Resources

- [Main README](README.md) - Project overview and quick start
- [Analysis Tests README](analysis/README.md) - Detailed analysis test documentation
- [Hub API Tests](https://github.com/konveyor/tackle2-hub/tree/main/test) - Upstream API test documentation
- [Konveyor CI](https://github.com/konveyor/ci) - Shared CI workflows and test configurations
- [Konveyor Operator](https://github.com/konveyor/operator) - Installation scripts and operator documentation

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.
