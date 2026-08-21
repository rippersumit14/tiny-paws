from typing import Literal

from pydantic import BaseModel, Field

AllowedAction = Literal[
    "PATROL_AREA",
    "INVESTIGATE_AREA",
    "SEARCH_POSITION",
    "GUARD_AREA",
    "CHASE_TARGET",
    "RETURN_TO_PATROL",
]


class LastSeenPlayer(BaseModel):
    position: list[float] = Field(default_factory=lambda: [0.0, 0.0, 0.0])
    time_seconds_ago: float = 999.0


class NoiseEvent(BaseModel):
    position: list[float] = Field(default_factory=lambda: [0.0, 0.0, 0.0])
    intensity: float = 1.0
    age_seconds: float = 0.0


class DecisionRequest(BaseModel):
    uncle_state: str = "patrol"
    uncle_position: list[float] = Field(default_factory=lambda: [0.0, 0.0, 0.0])
    visible_players: list[dict] = Field(default_factory=list)
    heard_noises: list[NoiseEvent] = Field(default_factory=list)
    last_seen_player: LastSeenPlayer | None = None
    recent_rooms: list[str] = Field(default_factory=list)
    difficulty: str = "medium"
    captured_recently: bool = False
    escape_count: int = 0


class DecisionResponse(BaseModel):
    action: AllowedAction
    target_area: str = "main_hall"
    urgency: float = Field(default=0.5, ge=0.0, le=1.0)
    reason: str = "rules"
