# The Log — A2UI Coach Server

An Express + TypeScript backend that holds the Anthropic API key, calls Claude
to produce structured coaching + UI widgets, and streams them to the Flutter
client as **A2UI** messages over SSE. It also proxies USDA FoodData Central
search so API keys stay server-side.

## Run

```bash
npm install
cp .env.example .env
# edit .env and set ANTHROPIC_API_KEY=...
npm run dev          # tsx watch, listens on PORT (default 8787), binds 0.0.0.0
```

For production:

```bash
npm run build
npm start
```

The server binds `0.0.0.0` so a physical phone on the same Wi-Fi can reach it;
the LAN URL is printed on boot. Point the Flutter app at that URL.

Without `ANTHROPIC_API_KEY` set, the coach endpoints still work — they stream a
graceful hardcoded fallback surface so the app functions offline.

## Endpoints

- `GET  /health` → `{ ok: true }`
- `POST /coach/daily-checkin` body `{ context }` → SSE A2UI surface
- `POST /coach/weekly-review` body `{ context, logs }` → SSE A2UI surface
- `POST /coach/chat` body `{ context, messages:[{role,text}] }` → SSE A2UI surface
- `POST /coach/photo-analysis` body `{ context, images:[<base64 jpeg>] }` → SSE A2UI surface (Claude vision)
- `GET  /usda/search?query=...` → `[{ fdcId, description, brand, cal, protein, carbs, fat, fiber }]`

## A2UI wire contract (SSE)

`Content-Type: text/event-stream`. Each `data:` line is one JSON message, in order:

1. `{"type":"beginStream"}`
2. `{"type":"createSurface","surfaceId":"s_<id>","root":"root"}`
3. one or more `{"type":"updateComponents","surfaceId":"s_<id>","components":[...]}` —
   the root Column is sent first, then children stream progressively in small batches.
4. `{"type":"endStream"}`

On error: `{"type":"error","message":"..."}` then `{"type":"endStream"}`.

## USDA notes

The proxy uses `USDA_API_KEY` (defaults to `DEMO_KEY`). `DEMO_KEY` is heavily
rate-limited — get a free key at <https://fdc.nal.usda.gov/api-key-signup> and
put it in `.env`. Network errors return `{ error, results: [] }` with HTTP 200
so the client degrades gracefully.

## Config

- `ANTHROPIC_API_KEY` — your Anthropic key (Claude model `claude-sonnet-4-6`).
- `USDA_API_KEY` — FoodData Central key (`DEMO_KEY` fallback).
- `PORT` — default `8787`.
