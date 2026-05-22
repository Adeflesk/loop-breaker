"""Unit tests for arc position computation (8-node loop mapping)."""

import pytest
from app.main import compute_arc_position


class TestArcPositionMapping:
    """Tests for the compute_arc_position function."""

    def test_stress_default_sublabel(self):
        """Stress with default/Overload/Tension/Urgency sublabels maps to Node 1."""
        pos, label = compute_arc_position("Stress", "Overload")
        assert pos == 1
        assert "Node 1 of 8" in label
        assert "Stress" in label

    def test_stress_burnout_sublabel(self):
        """Stress with Burnout sublabel maps to Node 4 (Neglecting Needs)."""
        pos, label = compute_arc_position("Stress", "Burnout")
        assert pos == 4
        assert "Node 4 of 8" in label
        assert "Neglecting Needs" in label

    def test_stress_burnt_out_sublabel(self):
        """Stress with Burnt-out sublabel maps to Node 4."""
        pos, label = compute_arc_position("Stress", "Burnt-out")
        assert pos == 4
        assert "Node 4 of 8" in label

    def test_procrastination_all_sublabels(self):
        """Procrastination maps to Node 3 regardless of sublabel."""
        for sublabel in ["Avoidance", "Perfectionism", "Fear of Failure", None]:
            pos, label = compute_arc_position("Procrastination", sublabel)
            assert pos == 3
            assert "Node 3 of 8" in label

    def test_anxiety_worry_dread(self):
        """Anxiety with Worry or Dread maps to Node 2 (Coping Struggle)."""
        for sublabel in ["Worry", "Dread"]:
            pos, label = compute_arc_position("Anxiety", sublabel)
            assert pos == 2
            assert "Node 2 of 8" in label
            assert "Coping Struggle" in label

    def test_anxiety_hypervigilance(self):
        """Anxiety with Hypervigilance maps to Node 5."""
        pos, label = compute_arc_position("Anxiety", "Hypervigilance")
        assert pos == 5
        assert "Node 5 of 8" in label
        assert "Hypervigilance" in label

    def test_anxiety_panic(self):
        """Anxiety with Panic maps to Node 5 (Hypervigilance)."""
        pos, label = compute_arc_position("Anxiety", "Panic")
        assert pos == 5
        assert "Node 5 of 8" in label

    def test_overwhelm_scattered(self):
        """Overwhelm with Scattered maps to Node 2 (Coping Struggle)."""
        pos, label = compute_arc_position("Overwhelm", "Scattered")
        assert pos == 2
        assert "Node 2 of 8" in label
        assert "Coping Struggle" in label

    def test_overwhelm_cognitive_overload(self):
        """Overwhelm with Cognitive Overload maps to Node 2."""
        pos, label = compute_arc_position("Overwhelm", "Cognitive Overload")
        assert pos == 2
        assert "Node 2 of 8" in label

    def test_overwhelm_paralysis(self):
        """Overwhelm with Paralysis maps to Node 4 (Neglecting Needs)."""
        pos, label = compute_arc_position("Overwhelm", "Paralysis")
        assert pos == 4
        assert "Node 4 of 8" in label
        assert "Neglecting Needs" in label

    def test_numbness_all_sublabels(self):
        """Numbness maps to Node 7 (Low Self-Esteem) regardless of sublabel."""
        for sublabel in ["Disconnected", "Apathy", "Exhaustion", "Freeze", None]:
            pos, label = compute_arc_position("Numbness", sublabel)
            assert pos == 7
            assert "Node 7 of 8" in label

    def test_shame_all_sublabels(self):
        """Shame maps to Node 8 regardless of sublabel."""
        for sublabel in ["Guilt", "Embarrassment", "Self-Blame", "Isolation", None]:
            pos, label = compute_arc_position("Shame", sublabel)
            assert pos == 8
            assert "Node 8 of 8" in label

    def test_isolation_all_sublabels(self):
        """Isolation maps to Node 8 (Shame context) regardless of sublabel."""
        for sublabel in ["Loneliness", "Withdrawal", "Avoidance of Others", None]:
            pos, label = compute_arc_position("Isolation", sublabel)
            assert pos == 8
            assert "Node 8 of 8" in label

    def test_unknown_node_defaults_to_node_1(self):
        """Unknown node defaults to Node 1 (Stress)."""
        pos, label = compute_arc_position("UnknownState", "SomeSublabel")
        assert pos == 1
        # Should be a sensible default label
        assert "Node" in label

    def test_none_sublabel_uses_default(self):
        """None sublabel should not break the mapping."""
        pos, label = compute_arc_position("Stress", None)
        assert pos == 1
        assert "Node 1 of 8" in label

    def test_all_valid_nodes_have_position(self):
        """All valid nodes should return a position."""
        valid_nodes = [
            "Procrastination",
            "Anxiety",
            "Stress",
            "Shame",
            "Overwhelm",
            "Numbness",
            "Isolation",
        ]
        for node in valid_nodes:
            pos, label = compute_arc_position(node, None)
            assert isinstance(pos, int)
            assert 1 <= pos <= 8
            assert "Node" in label
            assert "of 8" in label

    def test_label_format_consistency(self):
        """All labels should follow "Node N of 8 — Description" format."""
        test_cases = [
            ("Stress", "Overload"),
            ("Procrastination", "Avoidance"),
            ("Anxiety", "Worry"),
            ("Shame", "Guilt"),
        ]
        for node, sublabel in test_cases:
            pos, label = compute_arc_position(node, sublabel)
            assert f"Node {pos} of 8" in label


class TestArcPositionEdgeCases:
    """Edge case tests for arc position computation."""

    def test_case_sensitivity(self):
        """Test that node names are handled correctly."""
        # The function should handle title case nodes
        pos, label = compute_arc_position("Stress", "Overload")
        assert pos == 1

    def test_whitespace_in_sublabel(self):
        """Test sublabels with internal whitespace."""
        pos, label = compute_arc_position("Overwhelm", "Cognitive Overload")
        assert pos == 2  # Should match "Cognitive Overload"

    def test_return_tuple_structure(self):
        """Verify return value is always a tuple of (int, str)."""
        result = compute_arc_position("Stress", "Overload")
        assert isinstance(result, tuple)
        assert len(result) == 2
        assert isinstance(result[0], int)
        assert isinstance(result[1], str)


class TestArcPositionRobustness:
    """Robustness and error handling tests."""

    def test_empty_string_sublabel(self):
        """Empty string sublabel should not crash."""
        pos, label = compute_arc_position("Stress", "")
        assert isinstance(pos, int)
        assert isinstance(label, str)

    def test_very_long_sublabel(self):
        """Very long sublabel string should not crash."""
        long_sublabel = "A" * 1000
        pos, label = compute_arc_position("Stress", long_sublabel)
        assert isinstance(pos, int)
        assert isinstance(label, str)

    def test_special_characters_in_sublabel(self):
        """Special characters in sublabel should not crash."""
        pos, label = compute_arc_position("Stress", "Over!@#$%^&*()")
        assert isinstance(pos, int)
        assert isinstance(label, str)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
