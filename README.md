# Tiny Paws

Tiny Paws is transitioning into a downloadable Windows 3D multiplayer stealth-horror game about tiny dogs sneaking through Grumble Town, entering Uncle Grumble's moonlit manor, rescuing captured teammates, collecting keys, and escaping.

## Play

The public site is now a marketing and download website. It no longer embeds the playable game:

```text
https://rippersumit14.github.io/tiny-paws/
```

The multiplayer server remains live on Render for current room tests:

```text
https://tiny-paws.onrender.com
```

## About

The project now has two products:

- Windows game: Godot 4.7, staged native C++/GDExtension gameplay foundation, downloadable Windows export, and authoritative multiplayer.
- Website: React frontend, Express backend stub, and GitHub Pages deployment for information, screenshots, roadmap, GitHub links, and Windows downloads.

## Gameplay

Players enter a display name, host or join a short room code, choose AI Uncle or Player Uncle mode, ready up, then spawn outside at night in Grumble Town facing Uncle Grumble's manor. Dogs search for keys, use dog-scale routes, manage a small quick inventory, rescue captured friends, and escape.

## Features

- Godot 4 Windows-first client with a Windows Desktop export preset.
- Staged C++/GDExtension native gameplay foundation under `game/native`.
- Moonlit Grumble Town exterior pass with green grass, street lamps, neighboring homes, park, shed, garden, and manor silhouette.
- Node.js, TypeScript, and Colyseus authoritative multiplayer server.
- Configurable room capacity with `MAX_ROOM_PLAYERS`, defaulting to 8.
- Display-name validation without accounts or persistent profiles.
- Lobby state for host, difficulty, AI Uncle / Player Uncle mode, dog selection, Uncle volunteer intent, and ready status.
- TAB quick inventory with limited fictional boost items and cooldowns.
- Server-owned match state for objectives, captures, rescues, escapes, and results.
- Health endpoint at `GET /health`.

## Controls

- `WASD`: Move
- `Mouse`: Camera
- `Shift`: Sprint
- `E`: Interact
- `F`: Flashlight
- `Q`: Bark
- `Tab`: Quick inventory
- `Space`: Jump
- `Esc`: Pause

## Multiplayer Architecture

```text
Windows Godot Client
          |
          | WSS
          v
Node.js + TypeScript + Colyseus Server
          |
          v
Authoritative Room State
```

GitHub Pages only hosts the marketing/download website. It does not run the game or the Node.js server.

## Difficulty Modes

- Easy: 2 normal keys, slower and less perceptive Uncle Grumble.
- Medium: 3 normal keys, standard behavior.
- Hard: 3 normal keys plus 1 golden key, stronger detection and chase pressure.

## Tech Stack

- Game client: Godot 4.7, GDScript, and staged C++/GDExtension modules.
- Multiplayer server: Node.js, TypeScript, Colyseus, and Express.
- Website: React, Vite, Node.js, Express, and optional future MongoDB.
- Deployment target: GitHub Actions and GitHub Pages for the website, Render for the realtime server, GitHub Actions artifact workflow for Windows builds.

## Architecture

```text
tiny-paws/
  game/      Godot 4 client
  game/native/ C++/GDExtension gameplay foundation
  server/    Colyseus authoritative multiplayer backend
  website/   React/Express download website
  docs/      screenshots and project media
```

## Running Locally

Install server dependencies:

```bash
cd server
npm install
npm run dev
```

Open `game/project.godot` in Godot 4.7 and run the project. Local desktop/editor builds use `ws://localhost:2567/ws`.

## Running Multiplayer Server

```bash
cd server
npm run build
npm start
```

Configuration can be copied from `.env.example`. Do not commit `.env`.

Local Godot/editor clients connect to the JSON realtime gateway at:

```text
ws://localhost:2567/ws
```

Production Windows clients currently connect to the JSON realtime gateway at `wss://tiny-paws.onrender.com/ws`.

## Building Windows Game

Install Godot 4.7 with Windows export templates, then export the `game/` project using the Windows preset:

```powershell
mkdir builds/windows
godot --headless --path game --export-release "Windows Desktop" ../builds/windows/TinyPaws.exe
Compress-Archive -Path builds/windows/* -DestinationPath TinyPaws-Windows-x64.zip -Force
```

## Deployment

The deployment split is:

- GitHub Actions builds the React website and publishes static files to GitHub Pages.
- Render runs the Node.js realtime server with WebSocket support.
- The Windows Game Build workflow exports `TinyPaws.exe` and uploads `TinyPaws-Windows-x64.zip` as a build artifact.

GitHub Releases will be used for public Windows ZIP downloads once the first packaged build is promoted.

## Screenshots

Screenshots will be added under `docs/images/` after the playable scene has stable visuals.

## Roadmap

- Replace procedural placeholder models with authored production-quality dog, Uncle, manor, and town assets.
- Compile and activate the staged native C++/GDExtension gameplay module.
- Package the first Windows release ZIP and attach it to GitHub Releases.
- Expand AI Uncle and implement Player Uncle gameplay.
- Synchronize inventory, keys, doors, captures, rescues, escapes, and match results.
- Add settings, graphics presets, audio, chase polish, and edge-case recovery.

## Credits

Original prototype by the Tiny Paws contributors. Third-party assets, if added, are tracked in `ATTRIBUTIONS.md`.

## License

MIT. See `LICENSE`.
