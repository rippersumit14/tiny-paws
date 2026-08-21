import { createServer } from "node:http";
import { WebSocket, WebSocketServer } from "ws";
import { JsonRoomServer } from "../realtime/JsonRoomServer";

type JsonMessage = Record<string, any>;

async function main(): Promise<void> {
  const httpServer = createServer();
  new JsonRoomServer(new WebSocketServer({ server: httpServer, path: "/ws" }));

  await new Promise<void>((resolve) => {
    httpServer.listen(0, "127.0.0.1", resolve);
  });

  const address = httpServer.address();
  if (!address || typeof address === "string") {
    throw new Error("Unable to bind JSON gateway smoke server");
  }

  const endpoint = `ws://127.0.0.1:${address.port}/ws`;
  const host = await connect(endpoint);
  const guest = await connect(endpoint);

  try {
    host.send({ type: "create_room", name: "Sumit", dog: "Milo" });
    const created = await host.waitFor("room_created");
    const roomCode = created.roomCode as string;

    guest.send({ type: "join_room", roomCode, name: "Rohan", dog: "Bean" });
    await guest.waitFor("room_joined");
    await host.waitForState((state) => state.players.length === 2, "two players in lobby");

    host.send({ type: "set_game_mode", gameMode: "player_uncle" });
    guest.send({ type: "volunteer_uncle", volunteer: true });
    await host.waitForState((state) => state.gameMode === "player_uncle", "player uncle mode");

    host.send({ type: "set_ready", ready: true });
    guest.send({ type: "set_ready", ready: true });
    await host.waitForState(
      (state) => state.players.every((player: JsonMessage) => player.ready),
      "ready sync",
    );

    host.send({ type: "start_game" });
    await host.waitFor("match_started");
    await host.waitForState(
      (state) => state.matchState === "playing" && state.players.some((player: JsonMessage) => player.role === "uncle"),
      "match start",
    );

    host.send({
      type: "player_move",
      position: { x: 1.5, y: 0.6, z: -2.25 },
      yaw: 0.75,
    });
    const moved = await guest.waitFor("player_moved");
    if (moved.position.x !== 1.5 || moved.yaw !== 0.75) {
      throw new Error("Movement payload did not synchronize");
    }

    console.log("Tiny Paws JSON gateway smoke test passed.");
  } finally {
    host.close();
    guest.close();
    await new Promise<void>((resolve) => httpServer.close(() => resolve()));
  }
}

function connect(endpoint: string): Promise<TestSocket> {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(endpoint);
    const testSocket = new TestSocket(socket);
    socket.on("open", () => resolve(testSocket));
    socket.on("error", reject);
  });
}

class TestSocket {
  private readonly messages: JsonMessage[] = [];
  private readonly socket: WebSocket;

  constructor(socket: WebSocket) {
    this.socket = socket;
    this.socket.on("message", (data) => {
      this.messages.push(JSON.parse(data.toString()) as JsonMessage);
    });
  }

  send(message: JsonMessage): void {
    this.socket.send(JSON.stringify(message));
  }

  close(): void {
    this.socket.close();
  }

  async waitFor(type: string, timeoutMs = 3000): Promise<JsonMessage> {
    return this.waitForMessage((message) => message.type === type, type, timeoutMs);
  }

  async waitForState(
    assertion: (state: JsonMessage) => boolean,
    label: string,
    timeoutMs = 3000,
  ): Promise<JsonMessage> {
    const message = await this.waitForMessage(
      (candidate) => candidate.type === "state" && assertion(candidate.state as JsonMessage),
      label,
      timeoutMs,
    );
    return message.state as JsonMessage;
  }

  private async waitForMessage(
    assertion: (message: JsonMessage) => boolean,
    label: string,
    timeoutMs: number,
  ): Promise<JsonMessage> {
    const startedAt = Date.now();
    while (Date.now() - startedAt < timeoutMs) {
      const index = this.messages.findIndex(assertion);
      if (index >= 0) {
        const [message] = this.messages.splice(index, 1);
        return message;
      }
      await new Promise((resolve) => setTimeout(resolve, 25));
    }
    throw new Error(`Timed out waiting for ${label}`);
  }
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
