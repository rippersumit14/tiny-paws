import { type Client, Room } from "@colyseus/core";
import { env } from "../config/env";
import type { Difficulty } from "../config/constants";
import { generateRoomCode } from "../services/roomCode";
import {
  isFiniteVector3,
  parseDifficulty,
  parseDogArchetype,
  sanitizePlayerName,
} from "../services/validation";
import { KeyState, PlayerState, TinyPawsState } from "../schema/TinyPawsState";

const COLLARS = ["red", "blue", "green", "yellow", "pink", "teal", "white", "orange"];

const KEY_SPAWNS = [
  { id: "kitchen_counter", x: -6, y: 1.2, z: -2, golden: false },
  { id: "under_table", x: -2, y: 0.3, z: -4, golden: false },
  { id: "bathroom_shelf", x: 5, y: 1.4, z: 8, golden: false },
  { id: "study_desk", x: 6, y: 1.0, z: -4, golden: false },
  { id: "garage_crate", x: -8, y: 0.6, z: 5, golden: false },
  { id: "bedroom_corner", x: 2, y: 0.4, z: 9, golden: false },
  { id: "uncle_room_lockbox", x: -5, y: 0.8, z: 9, golden: true },
];

type JoinOptions = {
  name?: unknown;
  dog?: unknown;
};

export class TinyPawsRoom extends Room<{ state: TinyPawsState }> {
  maxClients = env.maxRoomPlayers;
  private readonly createdAt = Date.now();

  onCreate(): void {
    this.roomId = generateRoomCode();
    this.setState(new TinyPawsState());
    this.state.roomCode = this.roomId;
    this.state.maxPlayers = env.maxRoomPlayers;

    this.onMessage("setReady", (client, ready: unknown) => {
      const player = this.state.players.get(client.sessionId);
      if (!player || this.state.matchState !== "lobby") {
        return;
      }

      player.ready = Boolean(ready);
    });

    this.onMessage("selectDog", (client, dog: unknown) => {
      const player = this.state.players.get(client.sessionId);
      if (!player || this.state.matchState !== "lobby") {
        return;
      }

      player.dog = parseDogArchetype(dog);
    });

    this.onMessage("setDifficulty", (client, difficulty: unknown) => {
      if (!this.isHost(client)) {
        return;
      }

      const parsed = parseDifficulty(difficulty);
      if (parsed && this.state.matchState === "lobby") {
        this.state.difficulty = parsed;
      }
    });

    this.onMessage("startGame", (client) => {
      if (this.isHost(client)) {
        this.startMatch();
      }
    });

    this.onMessage("playerMove", (client, message: unknown) => {
      const player = this.state.players.get(client.sessionId);
      if (!player || player.lifecycle !== "active" || !isFiniteVector3(message)) {
        return;
      }

      player.position.set(message.x, message.y, message.z);
      const moveMessage = message as { x: number; y: number; z: number; yaw?: unknown };
      if (typeof moveMessage.yaw === "number" && Number.isFinite(moveMessage.yaw)) {
        player.yaw = moveMessage.yaw;
      }
    });

    this.onMessage("collectKey", (client, keyId: unknown) => {
      this.collectKey(client, keyId);
    });

    this.onMessage("capturePlayer", (client, targetSessionId: unknown) => {
      if (this.isHost(client) && typeof targetSessionId === "string") {
        this.capturePlayer(targetSessionId);
      }
    });

    this.onMessage("rescuePlayer", (client, targetSessionId: unknown) => {
      if (typeof targetSessionId === "string") {
        this.rescuePlayer(client.sessionId, targetSessionId);
      }
    });

    this.onMessage("escapePlayer", (client) => {
      this.escapePlayer(client.sessionId);
    });

    this.onMessage("returnToLobby", (client) => {
      if (this.isHost(client) && this.state.matchState === "results") {
        this.resetLobby();
      }
    });

    console.log(`[room ${this.roomId}] created`);
  }

  onAuth(_client: Client, options: JoinOptions): boolean {
    const validName = sanitizePlayerName(options.name);
    if (!validName) {
      throw new Error("INVALID_PLAYER_NAME");
    }

    if (this.clients.length >= env.maxRoomPlayers) {
      throw new Error("ROOM_IS_FULL");
    }

    if (this.state?.matchState && this.state.matchState !== "lobby") {
      throw new Error("GAME_ALREADY_STARTED");
    }

    return true;
  }

  onJoin(client: Client, options: JoinOptions): void {
    const player = new PlayerState();
    player.sessionId = client.sessionId;
    player.name = sanitizePlayerName(options.name) ?? "Player";
    player.dog = parseDogArchetype(options.dog);
    player.collar = COLLARS[this.state.players.size % COLLARS.length];
    player.host = this.state.players.size === 0;
    player.lifecycle = "active";

    if (player.host) {
      this.state.hostSessionId = client.sessionId;
    }

    this.state.players.set(client.sessionId, player);
    console.log(`[room ${this.roomId}] ${player.name} joined`);
  }

  onLeave(client: Client): void {
    const player = this.state.players.get(client.sessionId);
    if (!player) {
      return;
    }

    player.lifecycle = "disconnected";
    player.ready = false;
    console.log(`[room ${this.roomId}] ${player.name} disconnected`);

    if (client.sessionId === this.state.hostSessionId) {
      this.broadcast("hostDisconnected");
      this.disconnect();
      return;
    }

    this.finishIfMatchEnded();
  }

  onDispose(): void {
    console.log(`[room ${this.roomId}] disposed after ${Date.now() - this.createdAt}ms`);
  }

  private isHost(client: Client): boolean {
    return client.sessionId === this.state.hostSessionId;
  }

  private startMatch(): void {
    if (this.state.matchState !== "lobby") {
      return;
    }

    const players = this.playersList();
    if (players.length === 0 || players.some((player) => !player.ready)) {
      return;
    }

    this.state.matchState = "playing";
    this.state.startedAt = Date.now();
    this.configureObjectives(this.state.difficulty as Difficulty);
    players.forEach((player, index) => {
      player.lifecycle = "active";
      player.ready = false;
      player.position.set(index * 1.2, 0.35, 0);
    });

    console.log(`[room ${this.roomId}] match started on ${this.state.difficulty}`);
  }

  private configureObjectives(difficulty: Difficulty): void {
    this.state.keys.clear();
    this.state.keysCollected = 0;
    this.state.exitUnlocked = false;
    this.state.goldenKeyRequired = difficulty === "hard";
    this.state.normalKeysRequired = difficulty === "easy" ? 2 : 3;
    this.state.keysRequired = this.state.normalKeysRequired + (this.state.goldenKeyRequired ? 1 : 0);

    const normalSpawns = this.shuffle(KEY_SPAWNS.filter((spawn) => !spawn.golden)).slice(
      0,
      this.state.normalKeysRequired,
    );
    const selectedSpawns = [...normalSpawns];

    if (this.state.goldenKeyRequired) {
      const goldenSpawn = KEY_SPAWNS.find((spawn) => spawn.golden);
      if (goldenSpawn) {
        selectedSpawns.push(goldenSpawn);
      }
    }

    selectedSpawns.forEach((spawn) => {
      const key = new KeyState();
      key.id = spawn.id;
      key.golden = spawn.golden;
      key.position.set(spawn.x, spawn.y, spawn.z);
      this.state.keys.push(key);
    });
  }

  private collectKey(client: Client, keyId: unknown): void {
    const player = this.state.players.get(client.sessionId);
    if (
      this.state.matchState !== "playing" ||
      !player ||
      player.lifecycle !== "active" ||
      typeof keyId !== "string"
    ) {
      return;
    }

    const key = this.state.keys.find((candidate: KeyState) => candidate.id === keyId);
    if (!key || key.collected) {
      return;
    }

    const distance = Math.hypot(
      player.position.x - key.position.x,
      player.position.y - key.position.y,
      player.position.z - key.position.z,
    );

    if (distance > 2.25) {
      return;
    }

    key.collected = true;
    this.state.keysCollected += 1;
    this.broadcast("keyCollected", { keyId, by: client.sessionId });
    console.log(`[room ${this.roomId}] key ${keyId} collected`);

    if (this.state.keysCollected >= this.state.keysRequired) {
      this.state.exitUnlocked = true;
      this.broadcast("exitUnlocked");
      console.log(`[room ${this.roomId}] exit unlocked`);
    }
  }

  private capturePlayer(targetSessionId: string): void {
    const player = this.state.players.get(targetSessionId);
    if (!player || player.lifecycle !== "active") {
      return;
    }

    this.state.captureCount += 1;
    if (player.rescuesLeft <= 0) {
      player.lifecycle = "eliminated";
      this.broadcast("playerEliminated", { sessionId: targetSessionId, name: player.name });
    } else {
      player.lifecycle = "captured";
      player.position.set(0, 0.35, 12);
      this.broadcast("playerCaptured", { sessionId: targetSessionId, name: player.name });
    }

    console.log(`[room ${this.roomId}] ${player.name} captured`);
    this.finishIfMatchEnded();
  }

  private rescuePlayer(rescuerSessionId: string, targetSessionId: string): void {
    const rescuer = this.state.players.get(rescuerSessionId);
    const target = this.state.players.get(targetSessionId);
    if (
      this.state.matchState !== "playing" ||
      !rescuer ||
      !target ||
      rescuer.lifecycle !== "active" ||
      target.lifecycle !== "captured"
    ) {
      return;
    }

    const distance = Math.hypot(
      rescuer.position.x - target.position.x,
      rescuer.position.y - target.position.y,
      rescuer.position.z - target.position.z,
    );

    if (distance > 3) {
      return;
    }

    target.lifecycle = "active";
    target.rescuesLeft = Math.max(0, target.rescuesLeft - 1);
    target.position.set(rescuer.position.x + 0.75, rescuer.position.y, rescuer.position.z);
    this.state.rescueCount += 1;
    this.broadcast("playerRescued", {
      rescuerSessionId,
      targetSessionId,
      name: target.name,
    });
    console.log(`[room ${this.roomId}] ${target.name} rescued`);
  }

  private escapePlayer(sessionId: string): void {
    const player = this.state.players.get(sessionId);
    if (!player || player.lifecycle !== "active" || !this.state.exitUnlocked) {
      return;
    }

    if (player.position.z > 2.5 || Math.abs(player.position.x) > 3) {
      return;
    }

    player.lifecycle = "escaped";
    this.broadcast("playerEscaped", { sessionId, name: player.name });
    console.log(`[room ${this.roomId}] ${player.name} escaped`);
    this.finishIfMatchEnded();
  }

  private finishIfMatchEnded(): void {
    if (this.state.matchState !== "playing") {
      return;
    }

    const players = this.playersList();
    const anyInRound = players.some(
      (player) => player.lifecycle === "active" || player.lifecycle === "captured",
    );

    if (anyInRound) {
      return;
    }

    this.state.matchState = "results";
    this.state.results.players = players.length;
    this.state.results.escaped = players.filter((player) => player.lifecycle === "escaped").length;
    this.state.results.eliminated = players.filter(
      (player) => player.lifecycle === "eliminated",
    ).length;
    this.state.results.disconnected = players.filter(
      (player) => player.lifecycle === "disconnected",
    ).length;
    this.state.results.keysCollected = this.state.keysCollected;
    this.state.results.keysRequired = this.state.keysRequired;
    this.state.results.captures = this.state.captureCount;
    this.state.results.rescues = this.state.rescueCount;
    this.state.results.durationSeconds = Math.floor((Date.now() - this.state.startedAt) / 1000);
    this.broadcast("matchCompleted");
    console.log(`[room ${this.roomId}] match completed`);
  }

  private resetLobby(): void {
    this.state.matchState = "lobby";
    this.state.keys.clear();
    this.state.keysCollected = 0;
    this.state.exitUnlocked = false;
    this.state.captureCount = 0;
    this.state.rescueCount = 0;
    this.playersList().forEach((player) => {
      player.lifecycle = "active";
      player.ready = false;
      player.rescuesLeft = 2;
    });
  }

  private playersList(): PlayerState[] {
    return Array.from(this.state.players.values()) as PlayerState[];
  }

  private shuffle<T>(items: T[]): T[] {
    return [...items].sort(() => Math.random() - 0.5);
  }
}
