import {
  DIFFICULTIES,
  DOG_ARCHETYPES,
  type Difficulty,
  type DogArchetype,
  PLAYER_NAME_MAX_LENGTH,
} from "../config/constants";

const SAFE_NAME_PATTERN = /^[a-zA-Z0-9 _.-]+$/;

export function sanitizePlayerName(input: unknown): string | null {
  if (typeof input !== "string") {
    return null;
  }

  const trimmed = input.trim().replace(/\s+/g, " ");
  if (!trimmed || trimmed.length > PLAYER_NAME_MAX_LENGTH) {
    return null;
  }

  if (!SAFE_NAME_PATTERN.test(trimmed)) {
    return null;
  }

  return trimmed;
}

export function parseDogArchetype(input: unknown): DogArchetype {
  return DOG_ARCHETYPES.includes(input as DogArchetype)
    ? (input as DogArchetype)
    : "Milo";
}

export function parseDifficulty(input: unknown): Difficulty | null {
  return DIFFICULTIES.includes(input as Difficulty)
    ? (input as Difficulty)
    : null;
}

export function isFiniteVector3(input: unknown): input is { x: number; y: number; z: number } {
  if (!input || typeof input !== "object") {
    return false;
  }

  const value = input as Record<string, unknown>;
  return ["x", "y", "z"].every((axis) => Number.isFinite(value[axis]));
}

