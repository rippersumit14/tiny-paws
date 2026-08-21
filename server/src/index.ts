import { createServer } from "node:http";
import cors from "cors";
import express from "express";
import { Server } from "@colyseus/core";
import { monitor } from "@colyseus/monitor";
import { WebSocketTransport } from "@colyseus/ws-transport";
import { WebSocketServer } from "ws";
import { env } from "./config/env";
import { TinyPawsRoom } from "./rooms/TinyPawsRoom";
import { JsonRoomServer } from "./realtime/JsonRoomServer";

const app = express();
const httpServer = createServer(app);

app.use(cors());
app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({
    status: "ok",
    game: "tiny-paws",
    environment: env.nodeEnv,
    maxRoomPlayers: env.maxRoomPlayers,
    realtime: "json-websocket",
  });
});

if (env.nodeEnv !== "production") {
  app.use("/colyseus", monitor());
}

const colyseusTransport = new WebSocketTransport({ noServer: true });
colyseusTransport.attachToServer(httpServer, {
  filter: (req) => !req.url?.startsWith("/ws"),
});

const gameServer = new Server({
  transport: colyseusTransport,
});
gameServer.define("tiny_paws", TinyPawsRoom).filterBy(["roomCode"]);

new JsonRoomServer(new WebSocketServer({ server: httpServer, path: "/ws" }));

void gameServer.attach({ transport: gameServer.transport }).then(() => {
  httpServer.listen(env.port, () => {
    console.log(
      `Tiny Paws server listening on http://localhost:${env.port} with /ws realtime gateway`,
    );
  });
});
