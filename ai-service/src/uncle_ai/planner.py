from .decisions import DecisionRequest, DecisionResponse
from .memory import UncleMemory


class RulePlanner:
    def decide(self, request: DecisionRequest, memory: UncleMemory) -> DecisionResponse:
        difficulty = request.difficulty.lower()
        hard = difficulty == "hard"

        if request.visible_players:
            return DecisionResponse(
                action="CHASE_TARGET",
                target_area="visible_player",
                urgency=1.0,
                reason="player visible",
            )

        if request.heard_noises:
            loudest = max(request.heard_noises, key=lambda event: event.intensity)
            target_area = memory._area_from_position(loudest.position)
            return DecisionResponse(
                action="INVESTIGATE_AREA",
                target_area=target_area,
                urgency=min(1.0, 0.45 + loudest.intensity * 0.35),
                reason="noise memory",
            )

        if request.last_seen_player and request.last_seen_player.time_seconds_ago < (10.0 if hard else 6.0):
            return DecisionResponse(
                action="SEARCH_POSITION",
                target_area=memory._area_from_position(request.last_seen_player.position),
                urgency=0.78 if hard else 0.62,
                reason="last seen search",
            )

        favorite = memory.favorite_area()
        if favorite and difficulty in {"medium", "hard"}:
            return DecisionResponse(
                action="GUARD_AREA" if hard else "PATROL_AREA",
                target_area=favorite,
                urgency=0.6 if hard else 0.42,
                reason="player pattern",
            )

        return DecisionResponse(
            action="PATROL_AREA",
            target_area="main_hall",
            urgency=0.35,
            reason="default patrol",
        )
