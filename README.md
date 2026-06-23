# The Log — personal bodybuilding coach (Flutter + agentic A2UI coach)

A premium, locally-runnable fitness coaching app for one athlete. **Strava's
athletic clarity × Mid-Century-Modern / Japandi warmth.** Fixed native screens
for daily logging, **plus an agentic AI coach** that streams live **A2UI
generative-UI surfaces** for coaching moments — daily check-ins, weekly reviews,
photo analysis, exercise swaps, and chat.

> **Phase 1 · Shape Back** — three-phase plan to May 2027 (Shape Back → Build →
> Reveal). Cramp-safe legs (EQ), left-leg piriformis rehab, and beating the
> consistency-after-travel problem are baked into the copy and logic.

```
.
├── app/      Flutter mobile app (runs on your phone via `flutter run`)
├── server/   Node + Express (TypeScript) — the A2UI coach agent (holds your Anthropic key)
└── docs/     A2UI wire-protocol contract + architecture notes
```

The legacy "Weekly Dinner" web prototype still lives in the repo root
(`index.html`, `css/`, `js/`); its README is preserved at
[`docs/legacy-weekly-dinner-readme.md`](docs/legacy-weekly-dinner-readme.md). It
is unrelated to The Log and untouched by it.

---

## What's inside

### Mobile app (`/app`) — Flutter, Dart, fully local
- **Today** — date + Train/Rest toggle + weekday split, calorie total + 4
  animated **fuel columns** (protein = hero clay column; fat shows a **cap
  marker** — it's a ceiling), protein cue, cramp-guard/rehab checklist chips,
  today's lift preview + **Start lift**, bodyweight logging — **and a Coach card
  at the top that renders a live A2UI surface** (today's check-in + apply-able
  action widgets).
- **Train** — training + protein **streaks** (three-across Strava stat block),
  weekday exercises as cards with weight×reps set logging (default 3, add set),
  unilateral "**Lead with the LEFT**" cues, leg-day cramp banner.
- **Fuel** — day total + mini macros, logged meals (remove), quick-add library
  (2-col grid), **+ Add custom food → USDA FoodData Central** lookup.
- **Progress** — streaks, bodyweight **fl_chart** trend with a dashed reference
  line at **184 lb (Phase 1 goal)**, edge-to-edge check-in **photo** grid
  (capture → compress to 480px / JPEG q0.55 → store locally), and **"Analyze vs
  last check-in" → streams an A2UI comparison surface** from the coach.
- **Coach** — full-screen chat where the coach **responds with A2UI surfaces**
  (CoachMessage + ExerciseSwapCard/AdjustmentCard + Apply buttons), plus a
  **Weekly review** action that streams a full review surface.

Local storage via `sqflite` + `path_provider`; `image_picker` for check-ins;
`flutter_local_notifications` for a daily nudge; `fl_chart` for charts;
`google_fonts` (Bricolage Grotesque + Inter). Haptics, pull-to-refresh, and
reduce-motion are respected throughout. Every storage/network path has a
friendly empty/error state, and **A2UI surfaces degrade to plain text** if a
stream fails.

### Coach agent (`/server`) — Express + TypeScript
Holds your `ANTHROPIC_API_KEY` (never in the app). On each interaction it
gathers your live data, calls **Claude (`claude-sonnet-4-6`, full vision)**,
asks Claude for a **structured decision** (which trusted catalog widgets to show
+ values), then **streams that as A2UI `createSurface`/`updateComponents`
messages over SSE** — progressively, so coaching feels like it's thinking in
real time. Also proxies USDA search so keys stay server-side. **Works with no
API key**, serving sensible fallback coaching surfaces so the app never breaks.

### A2UI generative UI
A **trusted component catalog** of native Flutter widgets — `StatBlock`,
`FuelColumn`, `CoachMessage`, `AdjustmentCard`, `ExerciseSwapCard`,
`PhotoCompareCard`, `ChecklistChip`, `PrimaryButton`, `MetricRow`, `Divider`,
`SectionLabel`, `ProgressBar`, plus `Column`/`Row` layout. The agent may render
**only** these. **Apply** buttons emit events back to the app that mutate local
state (update today's targets, swap an exercise, log a food). The full wire
contract is in [`docs/A2UI_CONTRACT.md`](docs/A2UI_CONTRACT.md).

> **A note on the implementation:** this ships a faithful, self-contained A2UI
> renderer (trusted catalog + streamed `createSurface`/`updateComponents` +
> Apply events) so it compiles and runs today without depending on the
> early-stage `genui`/`genui_a2a`/`a2a` packages. The message shapes mirror the
> A2UI spec, so the renderer can be swapped for Google's GenUI SDK later with no
> change to the server. See `docs/A2UI_CONTRACT.md`.

---

## Run it locally

You need **Flutter ≥ 3.35.7** (with a connected phone or emulator) and
**Node ≥ 18**.

### 1. Start the coach server

```bash
cd server
npm install
cp .env.example .env
#  edit .env and set:
#    ANTHROPIC_API_KEY=sk-ant-...        (optional — without it you get fallback coaching)
#    USDA_API_KEY=DEMO_KEY               (optional — a free key lifts rate limits, see below)
npm run dev
```

The server prints the URL to point your phone at:

```
The Log coach server listening on 0.0.0.0:8787
  Local:   http://localhost:8787
  LAN:     http://192.168.1.20:8787  (point the phone here)
```

Note that **LAN** address — the web app and the mobile app both talk to it.

### 2. (Recommended for iPhone) Run as a web app — no Mac needed

Native iPhone builds require a Mac + Xcode + signing. To **just open it in
Safari on your iPhone** instead, run The Log as a Flutter web app served from
your computer:

```bash
cd app
./tool/setup.sh                                  # adds the web platform + web SQLite worker, runs pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

Then on your iPhone (on the **same wifi** as the computer), open Safari and go to:

```
http://<YOUR-COMPUTER-LAN-IP>:8080      # e.g. http://192.168.1.20:8080
```

Tap **Share → Add to Home Screen** to get an app-like icon (PWA). On web the app
**auto-points the coach at the same host**, so the Setup tab usually needs no
changes — just confirm with **Test connection**.

Notes for the web build:
- Data persists in the browser's **IndexedDB**; check-in photos are stored as
  compressed bytes in that same local DB (no filesystem needed).
- Daily push **notifications are mobile-only** (browsers can't schedule them
  here) — every other feature works.
- Coach surfaces render on web, but because browsers buffer streamed responses,
  they appear **all at once** when ready rather than component-by-component.
- This serves over plain **http on your LAN** (fine for personal use). A true
  installable/offline PWA needs **https hosting** — see "Always-on" below.

### 3. (Alternative) Run as a native mobile app

```bash
cd app
./tool/setup.sh        # scaffolds android/ios, runs `flutter pub get`, prints the
                       # permission lines to add (camera, notifications, internet)
# ...add the permissions it prints (one-time)...
flutter run            # with your phone connected via USB (or wifi debug)
```

> `tool/setup.sh` just runs `flutter create . --platforms=android,ios` (to
> generate version-matched native projects) followed by `flutter pub get`. If
> you prefer to do it by hand:
> ```bash
> cd app
> flutter create . --project-name the_log --platforms=android,ios
> flutter pub get
> flutter run
> ```

### 4. Point the app at your server

Open the **Setup** tab and set the **Coach server URL** (the web build usually
fills this in for you):

| Running on | Use |
|---|---|
| **iPhone via web (step 2)** | auto-set to the page host; e.g. `http://192.168.1.20:8787` |
| Physical phone, native (USB/wifi) | the **LAN** URL the server printed |
| Android emulator | `http://10.0.2.2:8787` |
| iOS simulator | `http://localhost:8787` |

Tap **Test connection** — you should see *Coach online ✓*. (Phone and computer
must be on the same wifi.)

### 5. (Optional) free USDA key

"+ Add custom food" uses USDA FoodData Central. It falls back to `DEMO_KEY`
(rate-limited). Get a free key at **https://fdc.nal.usda.gov/api-key-signup**
and put it in `server/.env` as `USDA_API_KEY=...`.

---

## Always-on (access without your computer running)

The local setup above needs your computer on and on the same wifi. To reach it
from anywhere, host the two pieces over **https**:

- **Web app** — `cd app && flutter build web`, then deploy `app/build/web/` to
  any static host (Netlify, Vercel, GitHub Pages, Cloudflare Pages). Over https
  the offline/installable **PWA** (service worker) fully kicks in.
- **Coach server** — deploy `/server` to a small host (Render, Fly.io, Railway)
  with `ANTHROPIC_API_KEY` set, behind https. Then put that server's https URL
  in the app's **Setup** tab (https → https avoids browser mixed-content
  blocking). Your training data still lives only in your browser's local DB.

---

## Native permissions added by `tool/setup.sh`

(Only needed for the native mobile build — skip for the web build.)

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```
**iOS** — `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key><string>Capture check-in photos to track progress.</string>
<key>NSPhotoLibraryUsageDescription</key><string>Pick check-in photos to track progress.</string>
```

---

## Quick command reference

```bash
# Coach server (needed for both web and mobile)
cd server && npm install && cp .env.example .env && npm run dev

# iPhone via web (first run) — then open http://<computer-LAN-IP>:8080 in Safari
cd app && ./tool/setup.sh
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080

# Native mobile (first run)
cd app && ./tool/setup.sh && flutter run

# Subsequent runs (web)
cd app && flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

All your data — meals, sets, bodyweight, photos — stays **on the device**. The
only network calls are to your own coach server (which talks to Claude + USDA).
