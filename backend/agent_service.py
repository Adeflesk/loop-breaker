import requests


def get_behavioral_analysis(user_input):
    response = requests.post(
        "http://localhost:11434/api/generate",
        json={
            "model": "behavioral-agent",
            "prompt": user_input,
            "stream": False,
            "format": "json",  # 2026 Ollama native JSON enforcement
        },
    )
    return response.json()["response"]


# Example usage
analysis = get_behavioral_analysis(
    "User biometrics show HR of 110bpm while stationary."
)
print(f"Agent Prediction: {analysis}")
