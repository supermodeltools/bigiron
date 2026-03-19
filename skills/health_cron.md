# Skill: Nightly Health Check (Phase 8)

**Category:** sdlc
**Phase:** 8 of 8 (autonomous, cron-driven)
**Requires:** Supermodel API (scripts/supermodel.sh), `guardrails` skill
**Schedule:** Nightly at 02:00 local time
**System:** Big Iron — AI-Native SDLC

## Purpose

Autonomously monitor architectural health over time. Detect drift between the intended architecture (encoded in guardrails and the "golden graph" snapshot) and the actual graph. Schedule refactoring tasks when entropy exceeds thresholds. Require no human trigger.

---

## Procedure

### Step 1 — Load baseline

Load the golden graph snapshot from the health_cron skill's stored state (updated each night that the check passes clean):

```
skill_view("health_cron", "golden_graph_summary.json")
```

If no baseline exists (first run), take one now and exit cleanly.

### Step 2 — Take current graph snapshot

```
POST /v1/graphs/domain
POST /v1/graphs/dependency
  include_metrics: true   # in-degree, out-degree, depth per module
```

Record:
- Module count
- Edge count (call edges, dependency edges)
- Domain distribution
- Top-10 modules by in-degree
- Circular dependency count
- Dead code node count

### Step 3 — Compute drift metrics

Compare current snapshot to golden baseline:

| Metric | Drift Threshold | Action |
|---|---|---|
| Circular dependency count | Any increase | Schedule refactor — high priority |
| Dead code node count | +5 or more | Schedule dead code sweep |
| Max in-degree | Exceeds guardrail threshold | Schedule coupling reduction |
| Domain violation count | Any increase | Schedule arch review |
| Dependency depth (max) | +2 or more | Flag for review |
| Edge count growth rate | >10% week-over-week | Alert — rapid coupling increase |

### Step 4 — Generate health report

```markdown
## Nightly Health Report — <date>

**Overall Status:** HEALTHY | DEGRADED | CRITICAL

### Metrics
| Metric | Baseline | Current | Delta | Status |
|---|---|---|---|---|
| Circular deps | <N> | <N> | <+/-N> | OK/WARN/CRIT |
| Dead code nodes | <N> | <N> | <+/-N> | OK/WARN/CRIT |
| Max module in-degree | <N> | <N> | <+/-N> | OK/WARN/CRIT |
| Domain violations | <N> | <N> | <+/-N> | OK/WARN/CRIT |
| Max dep depth | <N> | <N> | <+/-N> | OK/WARN/CRIT |
| Total edges | <N> | <N> | <+N> | OK/WARN/CRIT |

### Issues Detected
<list each issue with severity>

### Scheduled Tasks
<list any refactor or sweep tasks auto-created>
```

### Step 5 — Schedule remediation tasks

For each threshold exceeded, create a remediation task using the `todo` tool:

```
todo create
  title: "Refactor: <issue description>"
  priority: <high if CRITICAL, medium if WARN>
  context: "<health report excerpt>"
  skill: "refactor"
```

### Step 6 — Update baseline (if healthy)

If overall status is HEALTHY:

```
skill_manage write_file "health_cron" "golden_graph_summary.json"
  content: <current snapshot>
```

If DEGRADED or CRITICAL, do not update the baseline — it would mask the deterioration.

---

## Verification

- [ ] Baseline loaded (or created on first run)
- [ ] All 6 drift metrics computed
- [ ] Health report written to session output
- [ ] Remediation tasks created for all threshold violations
- [ ] Baseline updated only on HEALTHY status

---

## Pitfalls

- **Updating the baseline on a DEGRADED run.** This hides drift. Only update on clean runs.
- **Scheduling too many tasks at once.** Prioritize CRITICAL items. WARN items should queue behind in-progress work.
- **Running on a branch with in-progress changes.** The health check should run on the main branch only. Check the current branch before running.
- **Ignoring slow drift.** A 1% week-over-week increase in edge count is invisible per-night. Track week-over-week rates, not just nightly deltas.

---

## Cron Configuration

This skill is invoked by Hermes's built-in cron scheduler. Configuration in `~/.hermes/config.yaml`:

```yaml
cron:
  - name: nightly_health_check
    schedule: "0 2 * * *"
    task: "Run the health_cron skill on the current project graph"
    skill: health_cron
    branch_guard: main
```
