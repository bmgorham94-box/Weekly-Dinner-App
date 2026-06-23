// A2UI wire-contract helpers: SSE emit, catalog validation, progressive surface streaming.
import { Response } from "express";

// The catalog of allowed component types.
export const CATALOG_TYPES = new Set<string>([
  "Column",
  "Row",
  "CoachMessage",
  "StatBlock",
  "FuelColumn",
  "AdjustmentCard",
  "ExerciseSwapCard",
  "PhotoCompareCard",
  "ChecklistChip",
  "PrimaryButton",
  "MetricRow",
  "Divider",
  "SectionLabel",
  "ProgressBar",
]);

export interface A2uiComponent {
  id: string;
  type: string;
  props: Record<string, unknown>;
}

// A component as produced by Claude (no id assigned yet).
export interface RawComponent {
  type: string;
  props?: Record<string, unknown>;
}

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

/** Emit one SSE message: a single JSON object on a `data:` line. */
export function sendEvent(res: Response, payload: unknown): void {
  try {
    res.write(`data: ${JSON.stringify(payload)}\n\n`);
  } catch {
    // Connection may be gone; swallow so we never crash the process.
  }
}

/** Initialise the SSE response headers and flush them. */
export function initSse(res: Response): void {
  res.status(200);
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache, no-transform");
  res.setHeader("Connection", "keep-alive");
  res.setHeader("X-Accel-Buffering", "no");
  if (typeof res.flushHeaders === "function") {
    res.flushHeaders();
  }
}

/**
 * Validate raw components against the catalog, dropping unknown types,
 * and assign ids c0, c1, ... Returns the id-bearing children.
 */
export function buildChildren(raw: RawComponent[]): A2uiComponent[] {
  const out: A2uiComponent[] = [];
  let i = 0;
  for (const c of raw) {
    if (!c || typeof c.type !== "string" || !CATALOG_TYPES.has(c.type)) {
      continue;
    }
    out.push({
      id: `c${i++}`,
      type: c.type,
      props: c.props && typeof c.props === "object" ? c.props : {},
    });
  }
  return out;
}

/**
 * Stream a full A2UI surface to the client following the exact wire contract:
 * beginStream -> createSurface -> updateComponents (root Column first, then
 * children progressively in small batches) -> endStream.
 */
export async function streamSurface(
  res: Response,
  rawComponents: RawComponent[],
): Promise<void> {
  const surfaceId = `s_${Date.now().toString(36)}${Math.floor(
    Math.random() * 1e6,
  ).toString(36)}`;

  const children = buildChildren(rawComponents);

  sendEvent(res, { type: "beginStream" });
  sendEvent(res, { type: "createSurface", surfaceId, root: "root" });

  // Root Column first, referencing child ids in order.
  const root: A2uiComponent = {
    id: "root",
    type: "Column",
    props: { children: children.map((c) => c.id), gap: 12 },
  };
  sendEvent(res, {
    type: "updateComponents",
    surfaceId,
    components: [root],
  });
  await sleep(120);

  // Stream children progressively in small batches (1-3 per message).
  const BATCH = 2;
  for (let i = 0; i < children.length; i += BATCH) {
    const batch = children.slice(i, i + BATCH);
    sendEvent(res, {
      type: "updateComponents",
      surfaceId,
      components: batch,
    });
    await sleep(120);
  }

  sendEvent(res, { type: "endStream" });
}

/** Emit a graceful error surface ({error} then endStream) and stop. */
export function streamError(res: Response, message: string): void {
  sendEvent(res, { type: "error", message });
  sendEvent(res, { type: "endStream" });
}
