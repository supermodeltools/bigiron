# Skill: Dependency-Ordered Testing (Phase 5)

**Category:** sdlc
**Phase:** 5 of 8
**Requires:** Supermodel API (scripts/supermodel.sh)
**System:** Big Iron — AI-Native SDLC

## Purpose

Run tests in dependency order (leaves first, callers after) and scope the test run to exactly the blast radius of the change — no more, no less. This eliminates both under-testing (missing affected paths) and over-testing (running the full suite when only 3 functions changed).

---

## Procedure

### Step 1 — Retrieve the blast radius

From the Phase 1 plan, retrieve the pre-computed blast radius. If Phase 1 was not run (emergency fix path), compute it now:

```
POST /v1/analysis/impact?targets=file:fn
  symbol: "<changed symbol>"
```

Collect the full set of affected symbols: the changed function plus all transitive callers.

### Step 2 — Build the topological test order

```
POST /v1/graphs/call
  symbols: [<blast radius symbol list>]
  direction: "bottom-up"
```

This returns the call graph for the affected subgraph. Perform a topological sort:

1. Leaf functions (no callees in the subgraph) → test first
2. Their callers → test second
3. Continue up the call chain

**Rationale:** If a leaf fails, its callers will also fail. Testing leaves first surfaces the root cause immediately rather than producing a cascade of misleading failures.

### Step 3 — Map symbols to test files

For each symbol in the ordered list:

```
POST /v1/graphs/call  (search nodes)
  name: "<symbol>"
  include_test_file: true
```

Build the ordered test execution list. If a symbol has no associated test file, flag it as a coverage gap.

### Step 4 — Run tests in order

Execute tests in the topological order from Step 2. Stop at the first failure — a failure in a leaf invalidates all tests of its callers.

For each test run, record:
- Symbol tested
- Pass / Fail
- If fail: error message and stack trace

### Step 5 — Coverage gap report

```markdown
## Test Coverage Gaps

Symbols in blast radius with no associated test:
- <symbol name> (<file path>)
- ...

Required action: Write tests for these symbols before marking Phase 5 complete.
```

---

## Verification

- [ ] Test set covers 100% of blast radius symbols
- [ ] Tests executed in topological (leaf-first) order
- [ ] All coverage gaps documented (and tested if blocking)
- [ ] All tests pass before advancing to Phase 6

---

## Pitfalls

- **Running the full test suite instead of the blast radius subset.** This is slower and produces misleading signal when failures outside the blast radius are present.
- **Running tests in file order instead of dependency order.** A caller failing before its callee is tested makes root cause analysis much harder.
- **Treating a coverage gap as non-blocking.** Untested symbols in the blast radius are a quality hole. Document them at minimum; fill them before shipping.
- **Not re-running after a fix.** A test failure followed by a code fix must re-run from the beginning of the topological order — a fix to a leaf can cascade to change caller behavior.

---

## Token Notes

The blast radius and topological order come entirely from graph queries. No file reads required to build the test plan. Only open test files when actually running or writing tests.
