import config from "@colyseus/tools";
import { monitor } from "@colyseus/monitor";
import cors from "cors";
import express from "express";
import { env } from "./config/env";
import { TinyPawsRoom } from "./rooms/TinyPawsRoom";

export default config({
  initializeGameServer: (gameServer) => {
    gameServer.define("tiny_paws", TinyPawsRoom).filterBy(["roomCode"]);
  },

  initializeExpress: (app) => {
    app.use(cors());
    app.use(express.json());

    app.get("/health", (_req, res) => {
      res.json({
        status: "ok",
        game: "tiny-paws",
        environment: env.nodeEnv,
        maxRoomPlayers: env.maxRoomPlayers,
      });
    });

    if (env.nodeEnv !== "production") {
      app.use("/colyseus", monitor());
    }
  },

  beforeListen: () => {
    console.log(
      `Tiny Paws server starting on port ${env.port} with max room size ${env.maxRoomPlayers}`,
    );
  },
});

