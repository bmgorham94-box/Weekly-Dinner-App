// Wraps the Anthropic client and the structured-JSON coach call (with vision support).
import Anthropic from "@anthropic-ai/sdk";
import { buildSystemPrompt } from "./prompts";
import { RawComponent } from "./a2ui";

const MODEL = "claude-sonnet-4-6";

let client: Anthropic | null = null;

function getClient(): Anthropic | null {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) return null;
  if (!client) {
    client = new Anthropic({ apiKey: key });
  }
  return client;
}

export function hasApiKey(): boolean {
  return !!process.env.ANTHROPIC_API_KEY;
}

/**
 * Defensively parse a JSON object out of Claude's text output: strip
 * markdown fences, then take from the first `{` to the last `}`.
 */
export function parseSurfaceJson(text: string): RawComponent[] {
  if (!text) return [];
  let cleaned = text.trim();

  // Strip ```json ... ``` or ``` ... ``` fences if present.
  cleaned = cleaned.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "");

  const first = cleaned.indexOf("{");
  const last = cleaned.lastIndexOf("}");
  if (first === -1 || last === -1 || last <= first) return [];
  const slice = cleaned.slice(first, last + 1);

  let parsed: unknown;
  try {
    parsed = JSON.parse(slice);
  } catch {
    return [];
  }

  if (
    parsed &&
    typeof parsed === "object" &&
    Array.isArray((parsed as { surface?: unknown }).surface)
  ) {
    return (parsed as { surface: RawComponent[] }).surface;
  }
  return [];
}

export interface CoachRequest {
  context: unknown;
  endpoint: string;
  // Conversation turns for chat.
  messages?: Array<{ role: "user" | "assistant"; text: string }>;
  // Base64 JPEG strings for photo analysis.
  images?: string[];
  // A default user instruction when no messages are supplied.
  userText?: string;
}

/**
 * Call Claude once (non-streaming) and return the parsed, ordered list of
 * raw catalog components. Throws on API failure so the caller can fall back.
 */
export async function getCoachSurface(req: CoachRequest): Promise<RawComponent[]> {
  const c = getClient();
  if (!c) {
    throw new Error("ANTHROPIC_API_KEY missing");
  }

  const system = buildSystemPrompt(req.context, req.endpoint);

  const messages: Anthropic.MessageParam[] = [];

  if (req.images && req.images.length > 0) {
    const content: Anthropic.ContentBlockParam[] = [];
    for (const img of req.images) {
      if (typeof img !== "string" || img.length === 0) continue;
      // Strip any data: URL prefix defensively.
      const data = img.replace(/^data:image\/[a-zA-Z]+;base64,/, "");
      content.push({
        type: "image",
        source: {
          type: "base64",
          media_type: "image/jpeg",
          data,
        },
      });
    }
    content.push({
      type: "text",
      text:
        req.userText ||
        "Analyze these physique photos and produce the A2UI surface as instructed.",
    });
    messages.push({ role: "user", content });
  } else if (req.messages && req.messages.length > 0) {
    for (const m of req.messages) {
      if (!m || (m.role !== "user" && m.role !== "assistant")) continue;
      if (typeof m.text !== "string") continue;
      messages.push({ role: m.role, content: m.text });
    }
    // Ensure the conversation starts with a user turn.
    if (messages.length === 0 || messages[0].role !== "user") {
      messages.unshift({
        role: "user",
        content: req.userText || "Coach me based on my context.",
      });
    }
  } else {
    messages.push({
      role: "user",
      content: req.userText || "Coach me based on my context.",
    });
  }

  const response = await c.messages.create({
    model: MODEL,
    max_tokens: 2048,
    system,
    messages,
  });

  let text = "";
  for (const block of response.content) {
    if (block.type === "text") text += block.text;
  }

  return parseSurfaceJson(text);
}
