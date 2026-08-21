# Tiny Paws

Tiny Paws: Escape the Neighbor is a lightweight 3D co-op horror-comedy prototype about tiny dogs sneaking through an oversized house, finding keys, rescuing captured teammates, and escaping Uncle Grumble.

## Play

Public browser deployment is not live yet. The planned client deployment target is GitHub Pages for the Godot Web export, with the multiplayer server hosted separately on a free WebSocket-capable Node.js host.

## About

The prototype is built as a vertical slice: small scope, original low-poly assets, fast rounds, and an authoritative multiplayer architecture.

## Gameplay

Players enter a display name, create or join a short room code, ready up in the lobby, then explore the same house together. The team collects randomized keys, avoids Uncle Grumble, rescues captured friends, unlocks the exit, and escapes individually.

## Features

- Godot 4 client scaffold with menu, player controller, and starter world scenes.
- Node.js, TypeScript, and Colyseus authoritative multiplayer server.
- Configurable room capacity with `MAX_ROOM_PLAYERS`, defaulting to 8.
- Display-name validation without accounts or persistent profiles.
- Lobby state for host, difficulty, dog selection, and ready status.
- Server-owned match state for objectives, captures, rescues, escapes, and results.
- Health endpoint at `GET /health`.

## Controls

- `WASD`: Move
- `Mouse`: Camera
- `Shift`: Sprint
- `E`: Interact
- `F`: Flashlight
- `Q`: Bark
- `Space`: Jump
- `Esc`: Pause

## Multiplayer Architecture

```text
GitHub Pages Godot Web Client
          |
          | WSS
          v
Node.js + TypeScript + Colyseus Server
          |
          v
Authoritative Room State
```

GitHub Pages only hosts the static web client. It does not run the Node.js server.

## Difficulty Modes

- Easy: 2 normal keys, slower and less perceptive Uncle Grumble.
- Medium: 3 normal keys, standard behavior.
- Hard: 3 normal keys plus 1 golden key, stronger detection and chase pressure.

## Tech Stack

- Client: Godot 4.x and GDScript.
- Multiplayer server: Node.js, TypeScript, Colyseus, and Express.
- Deployment target: GitHub Actions and GitHub Pages for the web client, separate Node-compatible hosting for the server.

## Architecture

```text
tiny-paws/
  game/      Godot 4 client
  server/    Colyseus authoritative multiplayer backend
  docs/      screenshots and project media
```

## Running Locally

Install server dependencies:

```bash
cd server
npm install
npm run dev
```

Open `game/project.godot` in Godot 4.x and run the project. The local development server URL is `ws://localhost:2567`.

## Running Multiplayer Server

```bash
cd server
npm run build
npm start
```

Configuration can be copied from `.env.example`. Do not commit `.env`.

## Building Web Client

Install Godot 4.x with Web export templates, then export the `game/` project using a Web preset. The production client should use a `wss://` server URL configured through project settings or exported environment config.

## Deployment

The intended deployment split is:

- GitHub Actions builds the Godot Web client and publishes static files to GitHub Pages.
- A separate free Node-compatible host runs the Colyseus server with WebSocket support.

The exact server host will be selected and documented after validating current free-tier availability.

## Screenshots

Screenshots will be added under `docs/images/` after the playable scene has stable visuals.

## Roadmap

- Complete Godot movement, camera, and interaction loop.
- Build compact oversized house.
- Add key collection and escape objective.
- Add Uncle Grumble AI.
- Add capture, rescue, elimination, and spectator states.
- Connect Godot client to Colyseus server.
- Synchronize gameplay and results.
- Configure web export and deployment.

## Credits

Original prototype by the Tiny Paws contributors. Third-party assets, if added, are tracked in `ATTRIBUTIONS.md`.

## License

MIT. See `LICENSE`.

