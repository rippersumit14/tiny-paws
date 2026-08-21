from fastapi import FastAPI

from .uncle_ai.brain import UncleBrain
from .uncle_ai.decisions import DecisionRequest, DecisionResponse

app = FastAPI(title="Tiny Paws Uncle AI", version="0.1.0")
brain = UncleBrain()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "mode": brain.mode}


@app.post("/uncle/decision", response_model=DecisionResponse)
async def uncle_decision(request: DecisionRequest) -> DecisionResponse:
    return await brain.decide(request)
