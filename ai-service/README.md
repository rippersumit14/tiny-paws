# Tiny Paws AI Service

Optional local sidecar for high-level Uncle Grumble strategy.

The game works without this service. Run it only when testing adaptive AI:

```powershell
cd ai-service
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn src.main:app --host 127.0.0.1 --port 8765
```

Then launch the Godot game with:

```powershell
$env:TINY_PAWS_AI_MODE="adaptive"
$env:TINY_PAWS_AI_URL="http://127.0.0.1:8765/uncle/decision"
```

Optional local LLM mode can be tested with an Ollama-compatible endpoint:

```powershell
$env:AI_MODE="llm"
$env:OLLAMA_URL="http://127.0.0.1:11434/api/generate"
$env:OLLAMA_MODEL="llama3.2"
```

LLM output is validated into a fixed action set. Unknown actions or slow responses fall back to deterministic rule decisions.
