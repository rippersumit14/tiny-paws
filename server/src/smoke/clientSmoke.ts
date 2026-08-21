import { boot } from "@colyseus/testing";
import type { Room } from "@colyseus/sdk";
import appConfig from "../app.config";

type SmokeRoom = Room & {
  state: {
    roomCode: string;
    matchState: string;
    players: Map<string, { name: string; ready: boolean }>;
    keysRequired: number;
    keys: unknown[];
  };
};

type SmokePlayer = { name: string; ready: boolean };

async function waitFor(assertion: () => boolean, label: string, timeoutMs = 3000): Promise<void> {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    if (assertion()) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error(`Timed out waiting for ${label}`);
}

async function main(): Promise<void> {
  const testServer = await boot(appConfig);

  try {
    const hostRoom = (await testServer.sdk.create("tiny_paws", {
      name: "Sumit",
      dog: "Milo",
    })) as SmokeRoom;

    const guestRoom = (await testServer.sdk.joinById(hostRoom.roomId, {
      name: "Rohan",
      dog: "Bean",
    })) as SmokeRoom;

    await waitFor(() => hostRoom.state.players.size === 2, "host player sync");
    await waitFor(() => guestRoom.state.players.size === 2, "guest player sync");

    hostRoom.send("setDifficulty", "easy");
    hostRoom.send("setReady", true);
    guestRoom.send("setReady", true);

    await waitFor(() => players(hostRoom).every((player) => player.ready), "ready state sync");

    hostRoom.send("startGame");
    await waitFor(() => hostRoom.state.matchState === "playing", "match start");
    await waitFor(() => hostRoom.state.keysRequired === 2, "easy objective config");

    if (!/^[A-Z2-9]{4}$/.test(hostRoom.state.roomCode)) {
      throw new Error(`Unexpected room code: ${hostRoom.state.roomCode}`);
    }

    if (hostRoom.state.keys.length !== 2) {
      throw new Error(`Expected 2 spawned keys, got ${hostRoom.state.keys.length}`);
    }

    await guestRoom.leave();
    await hostRoom.leave();
    console.log("Tiny Paws Colyseus smoke test passed.");
  } finally {
    await testServer.shutdown();
  }
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});

function players(room: SmokeRoom): SmokePlayer[] {
  return Array.from(room.state.players.values()) as SmokePlayer[];
}
