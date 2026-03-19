"""
Tests: SDLC factory runner (orchestration layer).

Run last — orchestration is the top layer and depends on all others.
"""

import pytest
from app.orchestration.factory_runner import SDLCRunner, PhaseStatus, PhaseResult


class TestSDLCRunner:
    def setup_method(self):
        self.runner = SDLCRunner(
            feature="Test feature",
            codebase_root="/demo"
        )

    def test_initial_state(self):
        assert self.runner.current_phase == 0
        assert self.runner.can_advance()

    def test_record_phase_1(self):
        result = self.runner.record_phase(1, PhaseStatus.PASSED, "Plan complete")
        assert result.gate_passed
        assert self.runner.current_phase == 1

    def test_cannot_skip_phase(self):
        with pytest.raises(ValueError, match="Phase 2 cannot run before"):
            self.runner.record_phase(2, PhaseStatus.PASSED)

    def test_failed_phase_blocks_advancement(self):
        self.runner.record_phase(1, PhaseStatus.FAILED, "Plan failed")
        assert not self.runner.can_advance()
        with pytest.raises(ValueError, match="gate has not passed"):
            self.runner.record_phase(2, PhaseStatus.PASSED)

    def test_full_happy_path(self):
        for phase in range(1, 7):
            self.runner.record_phase(phase, PhaseStatus.PASSED, f"Phase {phase} ok")
        assert self.runner.current_phase == 6
        assert self.runner.can_advance()

    def test_status_report(self):
        self.runner.record_phase(1, PhaseStatus.PASSED, "Plan complete")
        report = self.runner.status_report()
        assert "Phase 1" in report
        assert "passed" in report
        assert "Phase 2" in report
        assert "pending" in report

    def test_violations_recorded(self):
        result = self.runner.record_phase(
            1, PhaseStatus.FAILED,
            violations=["Circular dependency: A → B → A"]
        )
        assert len(result.violations) == 1
        assert "Circular" in result.violations[0]
