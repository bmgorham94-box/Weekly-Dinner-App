# The Log — A2UI Wire Protocol Contract

This is the shared contract between the Flutter client (`/app`) and the Express
coach agent (`/server`). It implements the **A2UI pattern** (trusted component
catalog + streamed `createSurface`/`updateComponents` messages + Apply events)
with a lightweight native renderer so it compiles and runs without external
generative-UI packages. It can later be swapped for Google's `genui`/`a2a`
packages — the message shapes below mirror A2UI's component-tree + data-model
model.

## Transport

Server-Sent Events (SSE) over HTTP. The client POSTs a coach request and reads
an SSE stream of JSON A2UI messages. Each SSE `data:` line is one JSON message.

### Endpoints (all return `text/event-stream`)
- `POST /coach/daily-checkin` — body `{ context }`
- `POST /coach/weekly-review` — body `{ context, logs }`
- `POST /coach/chat`          — body `{ context, messages: [{role,text}] }`
- `POST /coach/photo-analysis`— body `{ context, images: [<base64 jpeg>, ...] }`
- `GET  /health`              — `{ ok: true }`

Every stream emits, in order:
1. `{"type":"beginStream"}`
2. `{"type":"createSurface","surfaceId":"s_<id>","root":"root"}`
3. one or more `{"type":"updateComponents","surfaceId":"s_<id>","components":[...]}`
   (progressive — components arrive in small batches so the UI "thinks" live)
4. `{"type":"endStream"}`
On error: `{"type":"error","message":"..."}` then `endStream`. Client degrades to
plain text.

## Components (the TRUSTED CATALOG — the agent may emit ONLY these `type`s)

Every component: `{ "id": string, "type": string, "props": { ... } }`.
Layout containers reference children by id.

| type             | props |
|------------------|-------|
| `Column`         | `{ children: string[], gap?: number }` |
| `Row`            | `{ children: string[], gap?: number }` |
| `CoachMessage`   | `{ text: string, tone?: "default"\|"warning"\|"good"\|"hero" }` |
| `StatBlock`      | `{ value: string, label: string, accent?: "clay"\|"sage"\|"ink"\|"amber" }` |
| `FuelColumn`     | `{ label: string, value: number, target: number, unit?: string, color?: "clay"\|"amber"\|"rose"\|"teal", cap?: bool }` |
| `AdjustmentCard` | `{ title: string, before: string, after: string, note?: string, applyAction?: string, applyValue?: any, applyLabel?: string }` |
| `ExerciseSwapCard`| `{ from: string, to: string, reason?: string, applyAction?: "swap_exercise", applyValue?: {from,to} }` |
| `PhotoCompareCard`| `{ verdict: string, leftLabel?: string, rightLabel?: string }` (images supplied by client) |
| `ChecklistChip`  | `{ label: string, checked?: bool }` |
| `PrimaryButton`  | `{ label: string, action?: string, value?: any, style?: "filled"\|"tonal" }` |
| `MetricRow`      | `{ label: string, value: string, color?: string }` |
| `Divider`        | `{}` |
| `SectionLabel`   | `{ text: string }` |
| `ProgressBar`    | `{ value: number (0..1), label?: string, color?: "clay"\|"sage"\|"amber" }` |

## Apply actions (Button/Card → client event → local state mutation)

When the user taps Apply/PrimaryButton, the client dispatches `action` + `value`:
- `set_targets` → value `{calories,protein,carbs,fat,fiber}` overrides today's targets
- `set_protein_target` → value `<int>` overrides protein target
- `swap_exercise` → value `{from,to}` swaps today's session exercise
- `log_food` → value `{name,cal,protein,carbs,fat,fiber}` adds a meal to today
- `toggle_checklist` → value `<label>` toggles a cramp-guard item
- `dismiss` → no-op (closes the surface)

Unknown actions are ignored gracefully (logged, surface stays).

## Agent → A2UI mapping

Claude is asked to return STRUCTURED JSON describing the coaching decision and
which catalog widgets to show (see `/server/src/prompts.ts`). The server
validates it and lowers it into the message sequence above. Claude never emits
raw A2UI or code — only a constrained decision object the server trusts and maps.
