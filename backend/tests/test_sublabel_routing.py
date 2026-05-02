"""Unit tests for sublabel-based intervention routing."""

import pytest
from app.interventions import INTERVENTIONS


class TestSublabelInterventionRouting:
    """Tests for the sublabel routing logic in INTERVENTIONS."""

    def test_procrastination_avoidance_variant(self):
        """Procrastination with Avoidance sublabel maps to Avoidance intervention."""
        intervention = INTERVENTIONS["Procrastination"].get("Avoidance") or INTERVENTIONS["Procrastination"].get(None)
        assert intervention is not None
        assert "5-Minute Sprint" in intervention["title"]
        assert "threatening" in intervention["education"]

    def test_procrastination_perfectionism_variant(self):
        """Procrastination with Perfectionism sublabel maps to Perfectionism intervention."""
        intervention = INTERVENTIONS["Procrastination"].get("Perfectionism") or INTERVENTIONS["Procrastination"].get(None)
        assert intervention is not None
        assert "Good Enough is Done" in intervention["title"]
        assert "perfect" in intervention["education"]

    def test_procrastination_fear_of_failure_variant(self):
        """Procrastination with Fear of Failure sublabel maps to unique intervention."""
        intervention = INTERVENTIONS["Procrastination"].get("Fear of Failure") or INTERVENTIONS["Procrastination"].get(None)
        assert intervention is not None
        assert "Failure Frame" in intervention["title"]

    def test_procrastination_default_fallback(self):
        """Procrastination with unmapped sublabel falls back to default."""
        intervention = INTERVENTIONS["Procrastination"].get("UnmappedSublabel") or INTERVENTIONS["Procrastination"].get(None)
        assert intervention is not None
        assert intervention == INTERVENTIONS["Procrastination"].get(None)

    def test_anxiety_hypervigilance_variant(self):
        """Anxiety with Hypervigilance sublabel maps to Threat Assessment Protocol."""
        intervention = INTERVENTIONS["Anxiety"].get("Hypervigilance") or INTERVENTIONS["Anxiety"].get(None)
        assert intervention is not None
        assert "Threat Assessment" in intervention["title"]
        assert "threat detector" in intervention["education"]

    def test_anxiety_panic_variant(self):
        """Anxiety with Panic sublabel uses grounding."""
        intervention = INTERVENTIONS["Anxiety"].get("Panic") or INTERVENTIONS["Anxiety"].get(None)
        assert intervention is not None
        assert "5-4-3-2-1" in intervention["title"]

    def test_anxiety_default_fallback(self):
        """Anxiety with unmapped sublabel falls back to grounding default."""
        intervention = INTERVENTIONS["Anxiety"].get("Worry") or INTERVENTIONS["Anxiety"].get(None)
        assert intervention is not None
        assert "5-4-3-2-1" in intervention["title"]

    def test_stress_burnout_variant(self):
        """Stress with Burnout sublabel maps to Recovery Reset."""
        intervention = INTERVENTIONS["Stress"].get("Burnout") or INTERVENTIONS["Stress"].get(None)
        assert intervention is not None
        assert "Recovery Reset" in intervention["title"]
        assert "parasympathetic" in intervention["education"]

    def test_stress_default_fallback(self):
        """Stress without Burnout uses physiological sigh default."""
        intervention = INTERVENTIONS["Stress"].get("Overload") or INTERVENTIONS["Stress"].get(None)
        assert intervention is not None
        assert "Physiological Sigh" in intervention["title"]

    def test_overwhelm_paralysis_variant(self):
        """Overwhelm with Paralysis sublabel maps to One Next Step."""
        intervention = INTERVENTIONS["Overwhelm"].get("Paralysis") or INTERVENTIONS["Overwhelm"].get(None)
        assert intervention is not None
        assert "One Next Step" in intervention["title"]
        assert "unfreezes" in intervention["education"]

    def test_overwhelm_default_fallback(self):
        """Overwhelm without Paralysis uses brain dump default."""
        intervention = INTERVENTIONS["Overwhelm"].get("Scattered") or INTERVENTIONS["Overwhelm"].get(None)
        assert intervention is not None
        assert "Brain Dump" in intervention["title"]

    def test_shame_has_no_variants(self):
        """Shame intervention is a simple dict (no variants yet)."""
        shame_intervention = INTERVENTIONS["Shame"]
        assert "title" in shame_intervention
        assert "task" in shame_intervention
        assert "education" in shame_intervention
        assert None not in shame_intervention  # No variants structure

    def test_numbness_has_no_variants(self):
        """Numbness intervention is a simple dict (no variants)."""
        numbness_intervention = INTERVENTIONS["Numbness"]
        assert "title" in numbness_intervention
        assert "task" in numbness_intervention
        assert "education" in numbness_intervention

    def test_isolation_has_no_variants(self):
        """Isolation intervention is a simple dict (no variants)."""
        isolation_intervention = INTERVENTIONS["Isolation"]
        assert "title" in isolation_intervention
        assert "task" in isolation_intervention
        assert "education" in isolation_intervention

    def test_all_interventions_have_required_fields(self):
        """All intervention dicts must have title, task, education, and type."""
        for node, intervention_data in INTERVENTIONS.items():
            if isinstance(intervention_data, dict) and None in intervention_data:
                # This is a variant dict
                for sublabel, intervention in intervention_data.items():
                    assert "title" in intervention, f"{node}:{sublabel} missing title"
                    assert "task" in intervention, f"{node}:{sublabel} missing task"
                    assert "education" in intervention, f"{node}:{sublabel} missing education"
                    assert "type" in intervention, f"{node}:{sublabel} missing type"
            else:
                # This is a simple intervention dict
                assert "title" in intervention_data, f"{node} missing title"
                assert "task" in intervention_data, f"{node} missing task"
                assert "education" in intervention_data, f"{node} missing education"
                assert "type" in intervention_data, f"{node} missing type"

    def test_intervention_types_are_valid(self):
        """All intervention types must be one of the defined categories."""
        valid_types = {"breathing", "grounding", "cognitive", "movement", "other"}

        def check_type(intervention):
            assert intervention["type"] in valid_types, f"Invalid type: {intervention['type']}"

        for node, intervention_data in INTERVENTIONS.items():
            if isinstance(intervention_data, dict) and None in intervention_data:
                for sublabel, intervention in intervention_data.items():
                    check_type(intervention)
            else:
                check_type(intervention_data)


class TestSublabelRoutingLogic:
    """Tests for the routing logic pattern used in main.py."""

    def _route_to_intervention(self, node, sublabel):
        """Simulate the routing logic from main.py."""
        intervention_options = INTERVENTIONS.get(node)
        if intervention_options and None in intervention_options:
            breaker = intervention_options.get(sublabel) or intervention_options.get(None)
        else:
            breaker = intervention_options or {
                "title": "General Check-in",
                "task": "Take a moment.",
                "education": "Checking in helps.",
                "type": "breathing"
            }
        return breaker

    def test_route_procrastination_avoidance(self):
        """Route Procrastination + Avoidance to Avoidance intervention."""
        result = self._route_to_intervention("Procrastination", "Avoidance")
        assert "5-Minute Sprint" in result["title"]
        assert "threatening" in result["education"]

    def test_route_procrastination_unmapped_sublabel(self):
        """Route Procrastination + unmapped sublabel to default."""
        result = self._route_to_intervention("Procrastination", "UnmappedSublabel")
        assert result == INTERVENTIONS["Procrastination"].get(None)

    def test_route_anxiety_hypervigilance(self):
        """Route Anxiety + Hypervigilance to Threat Assessment."""
        result = self._route_to_intervention("Anxiety", "Hypervigilance")
        assert "Threat Assessment" in result["title"]

    def test_route_anxiety_worry(self):
        """Route Anxiety + Worry to default grounding."""
        result = self._route_to_intervention("Anxiety", "Worry")
        assert "5-4-3-2-1" in result["title"]

    def test_route_shame_any_sublabel(self):
        """Shame has no variants, so any sublabel gets the same intervention."""
        result1 = self._route_to_intervention("Shame", "Guilt")
        result2 = self._route_to_intervention("Shame", "Embarrassment")
        result3 = self._route_to_intervention("Shame", None)
        assert result1 == INTERVENTIONS["Shame"]
        assert result2 == INTERVENTIONS["Shame"]
        assert result3 == INTERVENTIONS["Shame"]

    def test_route_unknown_node(self):
        """Unknown node falls back to generic check-in."""
        result = self._route_to_intervention("UnknownNode", "SomeSublabel")
        assert result["title"] == "General Check-in"
        assert result["type"] == "breathing"

    def test_route_none_sublabel_for_variant_state(self):
        """None sublabel correctly falls back to default for variant states."""
        result = self._route_to_intervention("Procrastination", None)
        assert result == INTERVENTIONS["Procrastination"].get(None)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
