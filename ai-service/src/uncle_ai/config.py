import os


class AIConfig:
    mode: str = os.getenv("AI_MODE", "rules").strip().lower()
    ollama_url: str = os.getenv("OLLAMA_URL", "http://127.0.0.1:11434/api/generate")
    ollama_model: str = os.getenv("OLLAMA_MODEL", "llama3.2")
    llm_timeout_seconds: float = float(os.getenv("LLM_TIMEOUT_SECONDS", "1.2"))
