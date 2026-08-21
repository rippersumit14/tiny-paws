# Tiny Paws Native Gameplay Foundation

Tiny Paws remains in Godot for this migration milestone, but important gameplay systems now have a C++/GDExtension home.

Planned native ownership:

- deterministic match rules and role assignment
- player/Uncle movement helpers
- AI sensing and navigation state helpers
- item cooldown and inventory validation
- anti-stuck/world-bounds safety checks

This folder is intentionally small at first. The GDScript systems stay active until each native module is built, tested, and swapped in safely.
