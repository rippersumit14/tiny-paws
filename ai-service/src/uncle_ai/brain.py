import json
import logging

import httpx
from pydantic import ValidationError

from .config import AIConfig
from .decisions import DecisionRequest, DecisionResponse
from .memory import UncleMemory
from .planner import RulePlanner

log = logging.getLogger("tiny_paws.uncle_ai")


class UncleBrain:
    def __init__(self) -> None:
        self.config = AIConfig()
        self.mode = self.config.mode
        self.memory = UncleMemory()
        self.rules = RulePlanner()

    async def decide(self, request: DecisionRequest) -> DecisionResponse:
        self.memory.update(request)
        rules_decision = self.rules.decide(request, self.memory)
        if self.mode != "llm":
            self.memory.remember_checked(rules_decision.target_area)
            return rules_decision

        llm_decision = await self._try_llm_decision(request, rules_decision)
        self.memory.remember_checked(llm_decision.target_area)
        return llm_decision

    async def _try_llm_decision(
        self,
        request: DecisionRequest,
        fallback: DecisionResponse,
    ) -> DecisionResponse:
        prompt = (
            "You are Uncle Grumble's high-level strategy planner in Tiny Paws. "
            "Return only JSON with action, target_area, urgency, reason. "
            "Allowed actions: PATROL_AREA, INVESTIGATE_AREA, SEARCH_POSITION, "
            "GUARD_AREA, CHASE_TARGET, RETURN_TO_PATROL. "
            "Never choose exact movement vectors. "
            f"Game state: {request.model_dump_json()}. "
            f"Rule fallback: {fallback.model_dump_json()}."
        )
        try:
            async with httpx.AsyncClient(timeout=self.config.llm_timeout_seconds) as client:
                response = await client.post(
                    self.config.ollama_url,
                    json={
                        "model": self.config.ollama_model,
                        "prompt": prompt,
                        "format": "json",
                        "stream": False,
                    },
                )
                response.raise_for_status()
            payload = response.json()
            raw = payload.get("response", "{}")
            parsed = json.loads(raw)
            decision = DecisionResponse.model_validate(parsed)
            decision.urgency = max(decision.urgency, fallback.urgency * 0.75)
            return decision
        except (httpx.HTTPError, json.JSONDecodeError, ValidationError, KeyError) as exc:
            log.warning("LLM unavailable or invalid; falling back to rules: %s", exc)
            return fallback
