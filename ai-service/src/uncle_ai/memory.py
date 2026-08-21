import time
from collections import Counter, deque

from .decisions import DecisionRequest


class UncleMemory:
    def __init__(self) -> None:
        self.room_visits: Counter[str] = Counter()
        self.noise_areas: Counter[str] = Counter()
        self.recent_checked: deque[str] = deque(maxlen=8)
        self.last_update = time.monotonic()

    def update(self, request: DecisionRequest) -> None:
        self._decay()
        for room in request.recent_rooms:
            self.room_visits[self._normalize_area(room)] += 1
        for noise in request.heard_noises:
            self.noise_areas[self._area_from_position(noise.position)] += max(1, round(noise.intensity * 2))

    def remember_checked(self, area: str) -> None:
        self.recent_checked.append(self._normalize_area(area))

    def favorite_area(self) -> str | None:
        scores = self.room_visits + self.noise_areas
        for area, _score in scores.most_common():
            if area not in self.recent_checked:
                return area
        return None

    def _decay(self) -> None:
        now = time.monotonic()
        if now - self.last_update < 20.0:
            return
        self.last_update = now
        for counter in [self.room_visits, self.noise_areas]:
            for key in list(counter.keys()):
                counter[key] = int(counter[key] * 0.72)
                if counter[key] <= 0:
                    del counter[key]

    def _area_from_position(self, position: list[float]) -> str:
        x = position[0] if len(position) > 0 else 0.0
        y = position[1] if len(position) > 1 else 0.0
        z = position[2] if len(position) > 2 else 0.0
        if y > 7.0:
            return "attic"
        if y > 3.0:
            return "upstairs"
        if z > 12.0:
            return "front_yard"
        if x < -5.0 and z < 0.0:
            return "kitchen"
        if x > 5.0 and z < 0.0:
            return "study"
        if z > 3.0:
            return "living_room"
        return "main_hall"

    def _normalize_area(self, area: str) -> str:
        return area.strip().lower().replace(" ", "_") or "main_hall"
