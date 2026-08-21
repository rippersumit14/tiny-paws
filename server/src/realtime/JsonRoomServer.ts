import type { IncomingMessage } from "node:http";
import { WebSocket, WebSocketServer } from "ws";
import { env } from "../config/env";
import type { Difficulty, DogArchetype } from "../config/constants";
import { generateRoomCode } from "../services/roomCode";
import {
  isFiniteVector3,
  parseDifficulty,
  parseDogArchetype,
  sanitizePlayerName,
} from "../services/validation";

type ClientMessage =
  | { type: "create_room"; name: unknown; dog?: unknown }
  | { type: "join_room"; roomCode: unknown; name: unknown; dog?: unknown }
  | { type: "set_ready"; ready: unknown }
  | { type: "set_difficulty"; difficulty: unknown }
  | { type: "start_game" }
  | { type: "player_move"; position: unknown; yaw?: unknown };

type Player = {
  sessionId: string;
  name: string;
  dog: DogArchetype;
  collar: string;
  ready: boolean;
  host: boolean;
  lifecycle: "active" | "disconnected";
  position: { x: number; y: number; z: number };
  yaw: number;
};

type RoomState = {
  roomCode: string;
  matchState: "lobby" | "playing";
  difficulty: Difficulty;
  maxPlayers: number;
  hostSessionId: string;
  players: Map<string, Player>;
};

type Peer = {
  socket: WebSocket;
  sessionId: string;
  roomCode: string | null;
};

const COLLARS = ["red", "blue", "green", "yellow", "pink", "teal", "white", "orange"];

export class JsonRoomServer {
  private readonly wss: WebSocketServer;
  private readonly rooms = new Map<string, RoomState>();
  private readonly peers = new Map<WebSocket, Peer>();

  constructor(wss: WebSocketServer) {
    this.wss = wss;
    this.wss.on("connection", (socket, request) => this.handleConnection(socket, request));
  }

  private handleConnection(socket: WebSocket, request: IncomingMessage): void {
    const peer: Peer = {
      socket,
      sessionId: crypto.randomUUID(),
      roomCode: null,
    };
    this.peers.set(socket, peer);
    this.send(peer, "connected", { sessionId: peer.sessionId, path: request.url ?? "/ws" });

    socket.on("message", (data) => this.handleMessage(peer, data.toString()));
    socket.on("close", () => this.handleClose(peer));
    socket.on("error", () => this.handleClose(peer));
  }

  private handleMessage(peer: Peer, raw: string): void {
    let message: ClientMessage;
    try {
      message = JSON.parse(raw) as ClientMessage;
    } catch {
      this.sendError(peer, "INVALID_MESSAGE");
      return;
    }

    switch (message.type) {
      case "create_room":
        this.createRoom(peer, message);
        break;
      case "join_room":
        this.joinRoom(peer, message);
        break;
      case "set_ready":
        this.setReady(peer, message.ready);
        break;
      case "set_difficulty":
        this.setDifficulty(peer, message.difficulty);
        break;
      case "start_game":
        this.startGame(peer);
        break;
      case "player_move":
        this.updateMove(peer, message.position, message.yaw);
        break;
      default:
        this.sendError(peer, "UNKNOWN_MESSAGE");
    }
  }

  private createRoom(peer: Peer, message: { name: unknown; dog?: unknown }): void {
    const name = sanitizePlayerName(message.name);
    if (!name) {
      this.sendError(peer, "INVALID_PLAYER_NAME");
      return;
    }

    const room: RoomState = {
      roomCode: this.nextRoomCode(),
      matchState: "lobby",
      difficulty: "medium",
      maxPlayers: env.maxRoomPlayers,
      hostSessionId: peer.sessionId,
      players: new Map(),
    };

    this.rooms.set(room.roomCode, room);
    peer.roomCode = room.roomCode;
    this.addPlayer(room, peer, name, parseDogArchetype(message.dog), true);
    this.send(peer, "room_created", { roomCode: room.roomCode, sessionId: peer.sessionId });
    this.broadcastState(room);
    console.log(`[json ${room.roomCode}] room created by ${name}`);
  }

  private joinRoom(peer: Peer, message: { roomCode: unknown; name: unknown; dog?: unknown }): void {
    const roomCode = typeof message.roomCode === "string" ? message.roomCode.trim().toUpperCase() : "";
    const name = sanitizePlayerName(message.name);
    const room = this.rooms.get(roomCode);

    if (!name) {
      this.sendError(peer, "INVALID_PLAYER_NAME");
      return;
    }
    if (!room) {
      this.sendError(peer, "INVALID_ROOM_CODE");
      return;
    }
    if (room.matchState !== "lobby") {
      this.sendError(peer, "GAME_ALREADY_STARTED");
      return;
    }
    if (room.players.size >= room.maxPlayers) {
      this.sendError(peer, "ROOM_IS_FULL");
      return;
    }

    peer.roomCode = room.roomCode;
    this.addPlayer(room, peer, name, parseDogArchetype(message.dog), false);
    this.send(peer, "room_joined", { roomCode: room.roomCode, sessionId: peer.sessionId });
    this.broadcastState(room);
    console.log(`[json ${room.roomCode}] ${name} joined`);
  }

  private addPlayer(
    room: RoomState,
    peer: Peer,
    name: string,
    dog: DogArchetype,
    host: boolean,
  ): void {
    room.players.set(peer.sessionId, {
      sessionId: peer.sessionId,
      name,
      dog,
      collar: COLLARS[room.players.size % COLLARS.length],
      ready: false,
      host,
      lifecycle: "active",
      position: { x: room.players.size * 1.2, y: 0.6, z: 0 },
      yaw: 0,
    });
  }

  private setReady(peer: Peer, ready: unknown): void {
    const room = this.getPeerRoom(peer);
    const player = room?.players.get(peer.sessionId);
    if (!room || !player || room.matchState !== "lobby") {
      return;
    }

    player.ready = Boolean(ready);
    this.broadcastState(room);
  }

  private setDifficulty(peer: Peer, difficulty: unknown): void {
    const room = this.getPeerRoom(peer);
    if (!room || peer.sessionId !== room.hostSessionId || room.matchState !== "lobby") {
      return;
    }

    const parsed = parseDifficulty(difficulty);
    if (parsed) {
      room.difficulty = parsed;
      this.broadcastState(room);
    }
  }

  private startGame(peer: Peer): void {
    const room = this.getPeerRoom(peer);
    if (!room || peer.sessionId !== room.hostSessionId || room.matchState !== "lobby") {
      return;
    }

    const players = Array.from(room.players.values());
    if (players.length === 0 || players.some((player) => !player.ready)) {
      this.sendError(peer, "PLAYERS_NOT_READY");
      return;
    }

    room.matchState = "playing";
    players.forEach((player, index) => {
      player.ready = false;
      player.position = { x: index * 1.2, y: 0.6, z: 0 };
      player.lifecycle = "active";
    });
    this.broadcast(room, "match_started", {});
    this.broadcastState(room);
    console.log(`[json ${room.roomCode}] match started`);
  }

  private updateMove(peer: Peer, position: unknown, yaw: unknown): void {
    const room = this.getPeerRoom(peer);
    const player = room?.players.get(peer.sessionId);
    if (!room || !player || room.matchState !== "playing" || !isFiniteVector3(position)) {
      return;
    }

    player.position = {
      x: clamp(position.x, -40, 40),
      y: clamp(position.y, -5, 12),
      z: clamp(position.z, -40, 40),
    };
    if (typeof yaw === "number" && Number.isFinite(yaw)) {
      player.yaw = yaw;
    }

    this.broadcast(room, "player_moved", {
      sessionId: peer.sessionId,
      position: player.position,
      yaw: player.yaw,
    }, peer);
  }

  private handleClose(peer: Peer): void {
    const room = this.getPeerRoom(peer);
    this.peers.delete(peer.socket);
    if (!room) {
      return;
    }

    const player = room.players.get(peer.sessionId);
    if (player) {
      room.players.delete(peer.sessionId);
      console.log(`[json ${room.roomCode}] ${player.name} disconnected`);
    }

    if (peer.sessionId === room.hostSessionId || room.players.size === 0) {
      this.broadcast(room, "host_disconnected", {});
      this.rooms.delete(room.roomCode);
      return;
    }

    this.broadcastState(room);
  }

  private getPeerRoom(peer: Peer): RoomState | null {
    return peer.roomCode ? this.rooms.get(peer.roomCode) ?? null : null;
  }

  private broadcastState(room: RoomState): void {
    this.broadcast(room, "state", { state: serializeRoom(room) });
  }

  private broadcast(room: RoomState, type: string, payload: object, except?: Peer): void {
    for (const peer of this.peers.values()) {
      if (peer.roomCode === room.roomCode && peer !== except) {
        this.send(peer, type, payload);
      }
    }
  }

  private send(peer: Peer, type: string, payload: object): void {
    if (peer.socket.readyState === WebSocket.OPEN) {
      peer.socket.send(JSON.stringify({ type, ...payload }));
    }
  }

  private sendError(peer: Peer, code: string): void {
    this.send(peer, "error", { code });
  }

  private nextRoomCode(): string {
    let roomCode = generateRoomCode();
    while (this.rooms.has(roomCode)) {
      roomCode = generateRoomCode();
    }
    return roomCode;
  }
}

function serializeRoom(room: RoomState): object {
  return {
    roomCode: room.roomCode,
    matchState: room.matchState,
    difficulty: room.difficulty,
    maxPlayers: room.maxPlayers,
    hostSessionId: room.hostSessionId,
    players: Array.from(room.players.values()),
  };
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

