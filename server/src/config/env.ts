import "dotenv/config";
import { DEFAULT_MAX_ROOM_PLAYERS, DEFAULT_PORT } from "./constants";

function readPositiveInt(name: string, fallback: number): number {
  const value = process.env[name];
  if (!value) {
    return fallback;
  }

  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

export const env = {
  nodeEnv: process.env.NODE_ENV ?? "development",
  port: readPositiveInt("PORT", DEFAULT_PORT),
  maxRoomPlayers: readPositiveInt("MAX_ROOM_PLAYERS", DEFAULT_MAX_ROOM_PLAYERS),
};

