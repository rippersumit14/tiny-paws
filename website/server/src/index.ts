import cors from "cors";
import express from "express";

const app = express();
const port = Number(process.env.PORT ?? 3100);

app.use(cors());
app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ status: "ok", product: "tiny-paws-website", version: "0.1.0" });
});

app.get("/api/download", (_req, res) => {
  res.json({
    version: "0.1.0",
    platform: "Windows 10 / 11 x64",
    fileName: "TinyPaws-Windows-x64.zip",
    releaseUrl: "https://github.com/rippersumit14/tiny-paws/releases",
    status: "pending-first-packaged-release",
  });
});

app.get("/api/patch-notes", (_req, res) => {
  res.json([
    {
      version: "0.1.0",
      title: "Windows-first migration begins",
      notes: [
        "Public website no longer embeds the browser game.",
        "Windows packaging workflow added.",
        "Native C++ gameplay foundation started.",
      ],
    },
  ]);
});

app.listen(port, () => {
  console.log(`Tiny Paws website API listening on http://localhost:${port}`);
});
