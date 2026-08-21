#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

class TinyPawsRules : public RefCounted {
  GDCLASS(TinyPawsRules, RefCounted);

protected:
  static void _bind_methods();

public:
  int keys_required_for_difficulty(const String &difficulty) const;
  bool golden_key_required(const String &difficulty) const;
  bool can_start_match(int player_count, bool all_ready, const String &game_mode) const;
  bool is_outside_world_bounds(const Vector3 &position) const;
  Vector3 safe_spawn_for_index(int index) const;
};

}
