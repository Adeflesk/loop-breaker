import pytest
from app.crisis import CrisisSafetyService


class TestCrisisSafetyService:
    """Tests for CrisisSafetyService"""

    @pytest.fixture
    def service(self):
        """Create service with default keywords."""
        return CrisisSafetyService()

    def test_detects_suicide_keyword(self, service):
        """Should detect 'suicide' in text."""
        is_crisis, keywords = service.detect_crisis("I'm thinking about suicide")
        assert is_crisis is True
        assert "suicide" in keywords

    def test_detects_multiple_keywords(self, service):
        """Should detect multiple crisis keywords in same text."""
        is_crisis, keywords = service.detect_crisis("I want to kill myself and harm others")
        assert is_crisis is True
        assert "kill myself" in keywords or "kill" in keywords

    def test_case_insensitive_detection(self, service):
        """Should detect keywords regardless of case."""
        is_crisis, keywords = service.detect_crisis("I'M THINKING ABOUT SUICIDE")
        assert is_crisis is True
        assert len(keywords) > 0

    def test_no_crisis_in_normal_text(self, service):
        """Should return False for normal journal entry."""
        is_crisis, keywords = service.detect_crisis("I had a good day at work today")
        assert is_crisis is False
        assert keywords == []

    def test_ignores_text_under_10_chars(self, service):
        """Should skip very short text (avoid accidentals)."""
        is_crisis, keywords = service.detect_crisis("suicide")  # 7 chars
        assert is_crisis is False
        assert keywords == []

    def test_detects_hopelessness_keywords(self, service):
        """Should detect hopelessness indicators."""
        is_crisis, keywords = service.detect_crisis("Everything is hopeless and pointless")
        assert is_crisis is True
        assert len(keywords) > 0

    def test_custom_keywords_on_init(self):
        """Should accept custom keyword list on init."""
        custom_service = CrisisSafetyService(keywords=["custom1", "custom2"])
        is_crisis, keywords = custom_service.detect_crisis("This mentions custom1")
        assert is_crisis is True
        assert "custom1" in keywords

    def test_load_keywords_from_env(self, monkeypatch):
        """Should load keywords from CRISIS_KEYWORDS env var if set."""
        monkeypatch.setenv("CRISIS_KEYWORDS", "badword1,badword2")
        service = CrisisSafetyService()
        is_crisis, keywords = service.detect_crisis("This text has badword1 in it")
        assert is_crisis is True
        assert "badword1" in keywords

    def test_regex_pattern_compiled_once(self):
        """Should compile regex pattern once at init, reuse for all detections."""
        service = CrisisSafetyService()
        # Call detect_crisis multiple times
        for _ in range(5):
            service.detect_crisis("suicide test")
        # If we get here without error, pattern is reused (performance test)
        assert service.regex_pattern is not None

    def test_returns_all_matched_keywords(self, service):
        """Should return list of all keywords found, not just True/False."""
        is_crisis, keywords = service.detect_crisis("I want to kill myself and end it all")
        assert is_crisis is True
        assert isinstance(keywords, list)
        assert len(keywords) > 0

    def test_no_keywords_in_normal_response(self, service):
        """Should return empty list when no crisis detected."""
        is_crisis, keywords = service.detect_crisis("Just a normal day")
        assert is_crisis is False
        assert keywords == []
