import { listen } from "@colyseus/tools";
import app from "./app.config";
import { env } from "./config/env";

void listen(app, env.port);

