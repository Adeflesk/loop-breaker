import os
import re
from typing import List, Tuple


class CrisisSafetyService:
    """Detects crisis indicators in user text."""

    DEFAULT_KEYWORDS = [
        # Core crisis indicators
        "suicide",
        "kill myself",
        "kill my self",
        "end it",
        "end my life",
        "harm myself",
        "self harm",
        "self-harm",
        "cut myself",
        "cutting",
        "overdose",
        "od",
        "take pills",
        # Hopelessness/despair
        "hopeless",
        "no point",
        "pointless",
        "give up",
        "can't go on",
        "better off dead",
        "everyone would be better without me",
        "nothing matters",
        "why bother",
        # Abuse/danger
        "abuse",
        "being hurt",
        "domestic violence",
        "hit me",
        "rape",
        "sexual assault",
    ]

    def __init__(self, keywords: List[str] = None):
        """
        Initialize service with keyword list.

        Args:
            keywords: List of crisis keywords. If None, loads from CRISIS_KEYWORDS env var or defaults.
        """
        if keywords is not None:
            self.keywords = keywords
        else:
            env_keywords = os.getenv("CRISIS_KEYWORDS", "")
            if env_keywords:
                self.keywords = [k.strip() for k in env_keywords.split(",")]
            else:
                self.keywords = self.DEFAULT_KEYWORDS

        self.regex_pattern = self._compile_pattern()

    def _compile_pattern(self) -> re.Pattern:
        """
        Compile regex pattern for all keywords (case-insensitive).
        Uses word boundaries to avoid partial matches.

        Returns:
            Compiled regex pattern
        """
        # Escape special regex chars in keywords
        escaped = [re.escape(k) for k in self.keywords]
        # Create pattern with word boundaries: \b(keyword1|keyword2|keyword3)\b
        pattern_str = r"\b(" + "|".join(escaped) + r")\b"
        return re.compile(pattern_str, re.IGNORECASE)

    def detect_crisis(self, text: str) -> Tuple[bool, List[str]]:
        """
        Detect crisis keywords in text.

        Args:
            text: User's journal entry text

        Returns:
            Tuple of (is_crisis: bool, detected_keywords: List[str])
        """
        # Skip very short text (< 10 chars, avoid accidentals)
        if len(text) < 10:
            return False, []

        # Find all keyword matches
        matches = self.regex_pattern.findall(text.lower())

        if matches:
            # Deduplicate while preserving order
            seen = set()
            unique_keywords = []
            for match in matches:
                if match not in seen:
                    unique_keywords.append(match)
                    seen.add(match)
            return True, unique_keywords

        return False, []
