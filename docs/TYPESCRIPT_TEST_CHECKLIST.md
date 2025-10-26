# TypeScript Analyzer Test Coverage Checklist

This checklist tracks what's needed to add test coverage for TypeScript/React analyzer support from [analyzer-lsp PR #930](https://github.com/konveyor/analyzer-lsp/pull/930).

## Prerequisites

- [ ] Verify analyzer-lsp PR #930 is merged and released
- [ ] Identify which Konveyor version includes the TypeScript analyzer support
- [ ] Confirm TypeScript/React rulesets exist in konveyor/rulesets repository

## 1. Sample Application Selection

- [ ] **Find or create a public TypeScript/React application** to use as test subject
  - Should include mix of `.ts`, `.tsx`, `.js`, `.jsx` files
  - Must have `package.json` with npm dependencies
  - Ideally demonstrates migration patterns (e.g., React version upgrades, Node.js modernization)
  - Small to medium size (fast analysis, < 5 minutes)
  - Public repository or one we can host

**Candidate apps to evaluate:**
- [ ] React TODO app with TypeScript
- [ ] Next.js starter template
- [ ] Create React App TypeScript template
- [ ] Other: _________________

**Selected app:**
- Repository URL: _________________
- Branch: _________________
- Description: _________________

## 2. Rule and Provider Validation

- [ ] **Identify available TypeScript/React rulesets**
  - Check https://github.com/konveyor/rulesets for:
    - [ ] Node.js migration rules
    - [ ] React version migration rules
    - [ ] TypeScript-specific patterns
    - [ ] Cloud-readiness rules for Node.js apps

- [ ] **Verify provider configuration details**
  - [ ] Confirm provider name (likely `"nodejs"` or `"typescript"`)
  - [ ] Check dependency label format (e.g., `konveyor.io/language=typescript`)
  - [ ] Verify file path prefix used by analyzer (e.g., `/shared/source/`)
  - [ ] Document tag categories used for TypeScript/React detection

## 3. Manual Analysis Run

- [ ] **Setup test environment with TypeScript analyzer**
  - [ ] Deploy Konveyor with analyzer-lsp that includes PR #930
  - [ ] Verify TypeScript language server is available
  - [ ] Confirm node_modules skipping is working (check analysis time ~5-7 seconds)

- [ ] **Run analysis on sample application**
  ```bash
  # Document the exact steps taken:
  # 1. Create application in Konveyor UI/API
  # 2. Configure analysis with targets: _________________
  # 3. Run analysis task
  # 4. Wait for completion
  ```

- [ ] **Capture analysis output**
  - [ ] Total effort (story points)
  - [ ] Number of insights/issues found
  - [ ] List of insights with:
    - Category (mandatory/potential/optional)
    - Description
    - Effort
    - RuleSet name
    - Rule ID
    - Sample incidents (file, line, message, code snippet)
  - [ ] Dependencies detected from package.json
    - Package names
    - Versions
    - Provider field value
    - Labels applied
    - Indirect vs direct dependencies
  - [ ] Analysis tags detected
    - Tag names (e.g., "React", "TypeScript", "npm")
    - Categories (e.g., "Web", "Language", "Build")

## 4. Test Case Implementation

- [ ] **Create test case file**: `analysis/tc_<app-name>.go`
  ```go
  package analysis

  import (
      "github.com/konveyor/go-konveyor-tests/hack/addon"
      "github.com/konveyor/tackle2-hub/api"
  )

  var MyTypescriptApp = TC{
      Name: "TypeScript/React App Analysis",
      Application: api.Application{
          Name:        "typescript-sample-app",
          Description: "Test TypeScript analyzer support from analyzer-lsp #930",
          Repository: &api.Repository{
              Kind:   "git",
              URL:    "https://github.com/___/___",
              Branch: "main",
          },
      },
      Task:     Analyze,
      WithDeps: true,  // Enable npm dependency analysis
      Labels: addon.Labels{
          Included: []string{
              "konveyor.io/target=cloud-readiness",
              // Add TypeScript-specific targets
          },
      },
      Analysis: api.Analysis{
          Effort: 0,  // Fill from manual run
          Insights: []api.Insight{
              // Copy from manual analysis output
          },
          Dependencies: []api.TechDependency{
              // Copy from manual analysis output
          },
      },
      AnalysisTags: []api.Tag{
          // Copy from manual analysis output
      },
  }
  ```

- [ ] **Register test case** in `analysis/test_cases.go`
  - [ ] Add to `Tier2TestCases` initially (less brittle)
  - [ ] Consider moving to `Tier1TestCases` after stabilization

- [ ] **Add documentation comment** explaining what the test validates:
  ```go
  // MyTypescriptApp validates TypeScript/React analyzer support including:
  // - Detection of .ts, .tsx, .js, .jsx files
  // - npm dependency analysis from package.json
  // - node_modules directory skipping (performance)
  // - TypeScript/React rule execution
  ```

## 5. Test Validation

- [ ] **Run test locally**
  ```bash
  export HUB_BASE_URL="http://$(minikube ip)/hub"
  DEBUG=1 TIER2=1 go test -v -count=1 ./analysis -run TestApplicationAnalysis
  ```

- [ ] **Verify test passes consistently**
  - [ ] Run 3+ times to check for flakiness
  - [ ] Check analysis time is reasonable (< 10 minutes)
  - [ ] Confirm all expected insights are found
  - [ ] Verify dependency count matches expectations

- [ ] **Handle test failures**
  - [ ] Document any known flaky scenarios
  - [ ] Adjust expected values if analyzer output varies
  - [ ] Consider filtering optional insights if too variable

## 6. CI Integration

- [ ] **Verify in GitHub Actions**
  - [ ] Push to branch and create PR
  - [ ] Check TIER2 workflow passes
  - [ ] Review CI logs for any timeout or performance issues
  - [ ] Confirm operator bundle version supports TypeScript analyzer

- [ ] **Update CI configuration if needed**
  - [ ] Check if specific operator version is required
  - [ ] Verify node_modules exclusion is working in CI environment

## 7. Documentation Updates

- [ ] **Update CONTRIBUTING.md** with TypeScript test case example
  - [ ] Add section showing how to add TypeScript/Node.js tests
  - [ ] Document npm dependency testing patterns

- [ ] **Update analysis/README.md**
  - [ ] Add TypeScript test case to examples
  - [ ] Document any TypeScript-specific configuration

- [ ] **Add comment in test case file**
  - [ ] Link to analyzer-lsp PR #930
  - [ ] Explain what features are being validated
  - [ ] Note any known limitations or edge cases

## 8. Future Enhancements

- [ ] **Consider additional test cases**
  - [ ] Pure TypeScript (no React)
  - [ ] React with JSX (no TypeScript)
  - [ ] Monorepo with multiple package.json files
  - [ ] Different Node.js/npm versions

- [ ] **Performance benchmarking**
  - [ ] Measure analysis time with/without node_modules exclusion
  - [ ] Document in test case or separate performance test

- [ ] **Edge cases**
  - [ ] Apps with yarn.lock or pnpm-lock.yaml
  - [ ] TypeScript configuration variations (tsconfig.json)
  - [ ] Scoped npm packages (@org/package)

## Notes and Blockers

**Current blockers:**
- _Document any blockers here_

**Open questions:**
- What is the exact provider name for TypeScript dependencies?
- Which npm/Node.js version is used by the analyzer?
- Are there specific TypeScript compiler options that affect analysis?

**Useful references:**
- analyzer-lsp PR: https://github.com/konveyor/analyzer-lsp/pull/930
- Konveyor rulesets: https://github.com/konveyor/rulesets
- Test case examples: `analysis/tc_tackle_testapp_public_deps.go`

---

**Status:** Not Started
**Assigned to:** _________________
**Target completion:** _________________
