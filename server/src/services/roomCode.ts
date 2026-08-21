import { ROOM_CODE_ALPHABET, ROOM_CODE_LENGTH } from "../config/constants";

export function generateRoomCode(): string {
  let code = "";

  for (let index = 0; index < ROOM_CODE_LENGTH; index += 1) {
    const charIndex = Math.floor(Math.random() * ROOM_CODE_ALPHABET.length);
    code += ROOM_CODE_ALPHABET[charIndex];
  }

  return code;
}

