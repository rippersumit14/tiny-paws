# Tiny Paws Bug Audit

## Current Fixes In This Pass

- Single-player was hidden behind old debug flow instead of a real menu path.
- Single-player ignored dog and difficulty selection.
- Solo capture auto-freed the player and could not produce a real failure state.
- Solo difficulty always used three keys and did not support Hard Golden Key.
- Uncle had one repetitive patrol route and no last-seen or suspicion memory.

## Remaining High-Priority Risks

- Multiplayer gameplay still only synchronizes movement and lobby state in the Godot JSON client; keys, captures, rescues, inventory, and AI Uncle state need full sync.
- Current dog and Uncle visuals are procedural placeholders, not final authored models.
- Stairs and dense furniture need hands-on collision testing in an interactive Windows run.
- Player Uncle role assignment exists server-side, but the Godot client does not yet switch controls/camera to Uncle gameplay.
- The native C++ module is staged but not compiled into an active GDExtension DLL yet.
- Settings, pause menu, audio, graphics presets, and release upload to GitHub Releases are still pending.

## Manual Test Checklist

- Start Single Player from the main menu for Easy, Medium, and Hard.
- Verify Easy requires two keys, Medium requires three, and Hard requires three plus Golden Key.
- Get captured twice and escape the cage by holding `E`.
- Verify the third capture shows `CAUGHT FOR GOOD` with Retry and Main Menu options.
- Verify `TAB` inventory opens and item cooldowns prevent spam.
- Host and join a multiplayer lobby after the menu split.
- Create a Player Uncle lobby with two players and confirm one role becomes Uncle after match start.
