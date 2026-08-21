#include "tiny_paws_rules.h"

#include <godot_cpp/variant/vector3.hpp>

using namespace godot;

void TinyPawsRules::_bind_methods() {
  ClassDB::bind_method(D_METHOD("keys_required_for_difficulty", "difficulty"), &TinyPawsRules::keys_required_for_difficulty);
  ClassDB::bind_method(D_METHOD("golden_key_required", "difficulty"), &TinyPawsRules::golden_key_required);
  ClassDB::bind_method(D_METHOD("can_start_match", "player_count", "all_ready", "game_mode"), &TinyPawsRules::can_start_match);
  ClassDB::bind_method(D_METHOD("is_outside_world_bounds", "position"), &TinyPawsRules::is_outside_world_bounds);
  ClassDB::bind_method(D_METHOD("safe_spawn_for_index", "index"), &TinyPawsRules::safe_spawn_for_index);
}

int TinyPawsRules::keys_required_for_difficulty(const String &difficulty) const {
  if (difficulty == "easy") {
    return 2;
  }
  return 3;
}

bool TinyPawsRules::golden_key_required(const String &difficulty) const {
  return difficulty == "hard";
}

bool TinyPawsRules::can_start_match(int player_count, bool all_ready, const String &game_mode) const {
  if (!all_ready || player_count <= 0) {
    return false;
  }
  if (game_mode == "player_uncle") {
    return player_count >= 2;
  }
  return true;
}

bool TinyPawsRules::is_outside_world_bounds(const Vector3 &position) const {
  return position.y < -8.0 || position.x < -120.0 || position.x > 120.0 || position.z < -120.0 || position.z > 120.0;
}

Vector3 TinyPawsRules::safe_spawn_for_index(int index) const {
  const int column = index % 4;
  const int row = index / 4;
  return Vector3(-3.6 + column * 2.4, 0.7, 32.0 + row * 1.8);
}
