"""
Orchestration layer — Big Iron SDLC runner.

Layer 0 in Big Iron's domain hierarchy (top layer).
Coordinates the 8-phase SDLC workflow using Hermes skills and Supermodel.
May call: all lower layers.
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


class PhaseStatus(Enum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    PASSED = "passed"
    FAILED = "failed"
    SKIPPED = "skipped"


@dataclass
class PhaseResult:
    phase: int
    name: str
    status: PhaseStatus
    output: str = ""
    violations: list = field(default_factory=list)
    gate_passed: bool = False


class SDLCRunner:
    """
    Coordinates the 8-phase Big Iron SDLC workflow.

    In a live deployment this is driven by Hermes via hermes run --skill <phase>.
    This class models the phase gate logic for programmatic use and testing.
    """

    PHASES = {
        1: "planning",
        2: "arch_check",
        3: "codegen",
        4: "quality_gates",
        5: "test_order",
        6: "code_review",
        7: "refactor",
        8: "health_cron",
    }

    def __init__(self, feature: str, codebase_root: str) -> None:
        self.feature = feature
        self.codebase_root = codebase_root
        self.results: dict[int, PhaseResult] = {}
        self.current_phase: int = 0

    def can_advance(self) -> bool:
        """Check if the current phase gate has passed."""
        if self.current_phase == 0:
            return True
        result = self.results.get(self.current_phase)
        return result is not None and result.gate_passed

    def record_phase(
        self,
        phase: int,
        status: PhaseStatus,
        output: str = "",
        violations: Optional[list] = None,
    ) -> PhaseResult:
        """Record the result of a phase. Enforces sequential ordering."""
        if phase != self.current_phase + 1:
            raise ValueError(
                f"Phase {phase} cannot run before phase {self.current_phase} is complete"
            )
        if not self.can_advance():
            raise ValueError(
                f"Phase {self.current_phase} gate has not passed — cannot advance to phase {phase}"
            )

        result = PhaseResult(
            phase=phase,
            name=self.PHASES[phase],
            status=status,
            output=output,
            violations=violations or [],
            gate_passed=(status == PhaseStatus.PASSED),
        )
        self.results[phase] = result
        self.current_phase = phase
        return result

    def status_report(self) -> str:
        """Return a formatted status report of all completed phases."""
        lines = [f"SDLC Status: {self.feature}", "=" * 50]
        for phase_num, phase_name in self.PHASES.items():
            result = self.results.get(phase_num)
            if result:
                icon = {"passed": "✓", "failed": "✗", "in_progress": "→", "skipped": "–"}.get(
                    result.status.value, "?"
                )
                lines.append(f"  {icon} Phase {phase_num}: {phase_name} — {result.status.value}")
                if result.violations:
                    for v in result.violations:
                        lines.append(f"      ⚠ {v}")
            else:
                lines.append(f"  · Phase {phase_num}: {phase_name} — pending")
        return "\n".join(lines)
