import "dotenv/config";
import express, { Request, Response } from "express";
import cors from "cors";
import os from "os";

import { initSse, streamSurface, streamError } from "./a2ui";
import type { RawComponent } from "./a2ui";
import { getCoachSurface, hasApiKey } from "./anthropic";
import { searchUsda } from "./usda";

const app = express();
app.use(cors());
app.use(express.json({ limit: "15mb" }));

const PORT = Number(process.env.PORT) || 8787;

// ---- Fallback surfaces (offline / no key / API failure) -------------------

const FALLBACK: Record<string, RawComponent[]> = {
  "daily-checkin": [
    {
      type: "CoachMessage",
      props: {
        text: "Travel's the test, not the gym. Hit your protein target today and get one quality session in — momentum beats perfection right now.",
        tone: "hero",
      },
    },
  ],
  "weekly-review": [
    {
      type: "CoachMessage",
      props: {
        text: "Couldn't reach the coach engine, but the plan holds: stay in a moderate deficit toward ~184 lb, keep legs cramp-safe, and log consistently. Review again when you're back online.",
        tone: "default",
      },
    },
  ],
  "photo-analysis": [
    {
      type: "CoachMessage",
      props: {
        text: "Photo analysis is offline right now. Keep shooting the same angle, same light, same time of day — consistency is what makes the comparison honest.",
        tone: "default",
      },
    },
  ],
  chat: [
    {
      type: "CoachMessage",
      props: {
        text: "I'm offline at the moment. Default move: protein first, train cramp-safe, and don't let a travel day become a travel week.",
        tone: "default",
      },
    },
  ],
};

function fallbackFor(endpoint: string): RawComponent[] {
  return FALLBACK[endpoint] ?? FALLBACK["chat"];
}

// Run a coach endpoint end-to-end over SSE, never leaving a hanging connection.
async function runCoach(
  res: Response,
  endpoint: string,
  build: () => Promise<RawComponent[]>,
): Promise<void> {
  initSse(res);
  try {
    let components: RawComponent[] = [];
    if (hasApiKey()) {
      try {
        components = await build();
      } catch (err) {
        // API call failed — fall back gracefully.
        components = [];
      }
    }
    if (!components || components.length === 0) {
      components = fallbackFor(endpoint);
    }
    await streamSurface(res, components);
  } catch (err) {
    const message = err instanceof Error ? err.message : "unknown error";
    streamError(res, message);
  } finally {
    res.end();
  }
}

// ---- Routes ---------------------------------------------------------------

app.get("/health", (_req: Request, res: Response) => {
  res.json({ ok: true });
});

app.post("/coach/daily-checkin", async (req: Request, res: Response) => {
  const { context } = req.body || {};
  await runCoach(res, "daily-checkin", () =>
    getCoachSurface({ context, endpoint: "daily-checkin" }),
  );
});

app.post("/coach/weekly-review", async (req: Request, res: Response) => {
  const { context, logs } = req.body || {};
  await runCoach(res, "weekly-review", () =>
    getCoachSurface({
      context,
      endpoint: "weekly-review",
      userText: `Here are my logs for the week:\n${JSON.stringify(
        logs ?? {},
      )}\nGive me a weekly review.`,
    }),
  );
});

app.post("/coach/chat", async (req: Request, res: Response) => {
  const { context, messages } = req.body || {};
  await runCoach(res, "chat", () =>
    getCoachSurface({
      context,
      endpoint: "chat",
      messages: Array.isArray(messages) ? messages : [],
    }),
  );
});

app.post("/coach/photo-analysis", async (req: Request, res: Response) => {
  const { context, images } = req.body || {};
  await runCoach(res, "photo-analysis", () =>
    getCoachSurface({
      context,
      endpoint: "photo-analysis",
      images: Array.isArray(images) ? images : [],
    }),
  );
});

app.get("/usda/search", async (req: Request, res: Response) => {
  try {
    const query = String(req.query.query ?? "");
    const result = await searchUsda(query);
    res.status(200).json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : "unknown error";
    res.status(200).json({ error: message, results: [] });
  }
});

// ---- Boot -----------------------------------------------------------------

function lanIp(): string {
  const ifaces = os.networkInterfaces();
  for (const name of Object.keys(ifaces)) {
    for (const iface of ifaces[name] ?? []) {
      if (iface.family === "IPv4" && !iface.internal) {
        return iface.address;
      }
    }
  }
  return "localhost";
}

app.listen(PORT, "0.0.0.0", () => {
  const ip = lanIp();
  console.log(`The Log coach server listening on 0.0.0.0:${PORT}`);
  console.log(`  Local:   http://localhost:${PORT}`);
  console.log(`  LAN:     http://${ip}:${PORT}  (point the phone here)`);
  console.log(
    `  Anthropic key: ${hasApiKey() ? "set" : "MISSING (serving fallback surfaces)"}`,
  );
});
