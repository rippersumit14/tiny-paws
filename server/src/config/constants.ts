export const DEFAULT_PORT = 2567;
export const DEFAULT_MAX_ROOM_PLAYERS = 8;
export const ROOM_CODE_LENGTH = 4;
export const ROOM_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export const PLAYER_NAME_MAX_LENGTH = 18;

export const DOG_ARCHETYPES = ["Milo", "Bean", "Rocket"] as const;
export type DogArchetype = (typeof DOG_ARCHETYPES)[number];

export const DIFFICULTIES = ["easy", "medium", "hard"] as const;
export type Difficulty = (typeof DIFFICULTIES)[number];

