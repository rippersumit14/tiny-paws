import { ArraySchema, MapSchema, Schema, type } from "@colyseus/schema";

export type MatchState =
  | "lobby"
  | "starting"
  | "playing"
  | "results"
  | "returning_to_lobby";

export type PlayerLifecycle =
  | "active"
  | "captured"
  | "eliminated"
  | "escaped"
  | "disconnected";

export class Vec3State extends Schema {
  @type("number") x = 0;
  @type("number") y = 0;
  @type("number") z = 0;

  set(x: number, y: number, z: number): void {
    this.x = x;
    this.y = y;
    this.z = z;
  }
}

export class PlayerState extends Schema {
  @type("string") sessionId = "";
  @type("string") name = "";
  @type("string") dog = "Milo";
  @type("string") collar = "red";
  @type("boolean") ready = false;
  @type("boolean") host = false;
  @type("string") lifecycle: PlayerLifecycle = "active";
  @type("number") rescuesLeft = 2;
  @type(Vec3State) position = new Vec3State();
  @type("number") yaw = 0;
}

export class KeyState extends Schema {
  @type("string") id = "";
  @type("boolean") golden = false;
  @type("boolean") collected = false;
  @type(Vec3State) position = new Vec3State();
}

export class NeighborState extends Schema {
  @type("string") aiState = "patrol";
  @type("string") targetSessionId = "";
  @type(Vec3State) position = new Vec3State();
}

export class ResultsState extends Schema {
  @type("number") players = 0;
  @type("number") escaped = 0;
  @type("number") eliminated = 0;
  @type("number") disconnected = 0;
  @type("number") keysCollected = 0;
  @type("number") keysRequired = 0;
  @type("number") captures = 0;
  @type("number") rescues = 0;
  @type("number") durationSeconds = 0;
}

export class TinyPawsState extends Schema {
  @type("string") roomCode = "";
  @type("string") matchState: MatchState = "lobby";
  @type("string") difficulty = "medium";
  @type("number") maxPlayers = 8;
  @type("string") hostSessionId = "";
  @type("number") keysRequired = 3;
  @type("number") normalKeysRequired = 3;
  @type("boolean") goldenKeyRequired = false;
  @type("number") keysCollected = 0;
  @type("boolean") exitUnlocked = false;
  @type("number") startedAt = 0;
  @type("number") captureCount = 0;
  @type("number") rescueCount = 0;
  @type({ map: PlayerState }) players = new MapSchema<PlayerState>();
  @type([KeyState]) keys = new ArraySchema<KeyState>();
  @type(NeighborState) neighbor = new NeighborState();
  @type(ResultsState) results = new ResultsState();
}

