export const ENDPOINT = "https://api.deepseek.com/chat/completions";
export const MODEL = "deepseek-flash";
export const MAX_BODY = 16 * 1024;
export const MAX_RESPONSE = 256 * 1024;
export const UNAVAILABLE = { available: false, reason: "unavailable" } as const;

const ACTIONS = ["fold", "check", "call", "raise", "all_in"] as const;
type Action = typeof ACTIONS[number];
export interface Fact {
  decision_id: number;
  actual_action: Action;
  actual_amount: number;
  alternative_action: Action;
  alternative_amount: number;
  actual_ev_bb: number;
  alternative_ev_bb: number;
  gap_bb: number;
  assessment: "close" | "compare";
  sample_count: number;
}
export interface Review {
  analysis_version: 1;
  locale: "en" | "zh_CN";
  decisions: Fact[];
}
export interface ReviewItem {
  decision_id: number;
  actual_action: Action;
  alternative_action: Action;
  assessment: Fact["assessment"];
  explanation: string;
  next_step: string;
}
export type ReviewResult = { items: ReviewItem[] } | typeof UNAVAILABLE;

const FACT_KEYS = [
  "decision_id", "actual_action", "actual_amount", "alternative_action",
  "alternative_amount", "actual_ev_bb", "alternative_ev_bb", "gap_bb",
  "assessment", "sample_count",
].sort().join();

function record(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw Error("object");
  return value as Record<string, unknown>;
}

export function validateInput(value: unknown): Review {
  const input = record(value);
  if (Object.keys(input).sort().join() !== "analysis_version,decisions,locale" ||
      input.analysis_version !== 1 || (input.locale !== "en" && input.locale !== "zh_CN")) {
    throw Error("request shape");
  }
  if (!Array.isArray(input.decisions) || input.decisions.length < 1 || input.decisions.length > 12) {
    throw Error("decisions");
  }
  const seen = new Set<number>();
  for (const value of input.decisions) {
    const fact = record(value);
    if (Object.keys(fact).sort().join() !== FACT_KEYS) throw Error("fact shape");
    for (const [key, maximum] of [
      ["decision_id", 4096], ["actual_amount", 1e9],
      ["alternative_amount", 1e9], ["sample_count", 100000],
    ] as const) {
      const number = fact[key];
      if (typeof number !== "number" || !Number.isInteger(number) || number < 0 || number > maximum) {
        throw Error("integer fact");
      }
    }
    const id = fact.decision_id as number;
    if (id < 1 || seen.has(id) || (fact.sample_count as number) < 1) throw Error("reference");
    seen.add(id);
    for (const key of ["actual_action", "alternative_action"] as const) {
      if (!ACTIONS.includes(fact[key] as Action)) throw Error("action");
    }
    if (fact.assessment !== "close" && fact.assessment !== "compare") throw Error("assessment");
    for (const key of ["actual_ev_bb", "alternative_ev_bb", "gap_bb"] as const) {
      const number = fact[key];
      if (typeof number !== "number" || !Number.isFinite(number) || Math.abs(number) > 1e9) {
        throw Error("numerical fact");
      }
    }
  }
  return input as unknown as Review;
}

export function makePayload(review: Review) {
  const language = review.locale === "en" ? "English" : "Simplified Chinese";
  const instructions =
    `Write a brief poker practice explanation in ${language} using ONLY supplied local-analysis facts. ` +
    'Return JSON only: {"items":[{"decision_id":1,"actual_action":"call",' +
    '"alternative_action":"fold","assessment":"compare","explanation":"Short qualitative explanation",' +
    '"next_step":"Short practice suggestion"}]}. ' +
    "Choose one to three distinct supplied decisions. Copy decision_id, actual_action, " +
    "alternative_action and assessment exactly from that decision. " +
    "Each text must be at most 180 characters. Do not write numbers, percentages, card names, " +
    "imagined holdings, outcomes, or actions other than the two supplied actions in either text. " +
    "The UI supplies all numeric values. These are approximate neutral-range sampled EVs, " +
    "not optimal play. For close, acknowledge unresolved sampling uncertainty and do not call " +
    "the action a mistake. Avoid the words mistake, wrong, incorrect, should have, 错误, 失误 and 必须 " +
    "even in a negation. Describe uncertainty directly instead. " +
    "For compare, invite comparison of sizing and future risk. Never guarantee success.";
  return {
    model: MODEL, stream: false, thinking: { type: "disabled" }, max_tokens: 1200,
    response_format: { type: "json_object" },
    messages: [
      { role: "system", content: instructions },
      { role: "user", content: JSON.stringify({ decisions: review.decisions }) },
    ],
  };
}

export function validateOutput(envelope: unknown, facts: Fact[]): { items: ReviewItem[] } {
  const choices = record(envelope).choices;
  if (!Array.isArray(choices) || choices.length !== 1) throw Error("choices");
  const choice = record(choices[0]);
  if (choice.finish_reason !== "stop") throw Error("incomplete");
  const content = record(choice.message).content;
  // Match Python's Unicode code-point limit, rather than UTF-8 bytes or UTF-16 units.
  if (typeof content !== "string" || Array.from(content).length > 6000) throw Error("content");
  const items = record(JSON.parse(content)).items;
  if (!Array.isArray(items) || items.length < 1 || items.length > 3) throw Error("items");
  const byId = new Map(facts.map(fact => [fact.decision_id, fact]));
  const seen = new Set<number>();
  const aliases: Record<Action, string[]> = {
    fold: ["fold", "弃牌"], check: ["check", "过牌", "让牌"], call: ["call", "跟注"],
    raise: ["raise", "加注"], all_in: ["all-in", "all in", "全下"],
  };
  const output: ReviewItem[] = [];
  for (const value of items) {
    const item = record(value);
    const id = item.decision_id;
    if (typeof id !== "number" || !Number.isInteger(id) || seen.has(id)) throw Error("reference");
    const fact = byId.get(id);
    if (!fact) throw Error("reference");
    for (const key of ["actual_action", "alternative_action", "assessment"] as const) {
      if (item[key] !== fact[key]) throw Error("unsupported fact");
    }
    const texts = { explanation: "", next_step: "" };
    for (const key of ["explanation", "next_step"] as const) {
      const text = item[key];
      if (typeof text !== "string" || !text.trim() || Array.from(text).length > 180) throw Error("text");
      if (/[0-9０-９%％♠♣♥♦<>]|guarantee|always win|GTO|https?:\/\/|保证|必胜|百分之/i.test(text)) {
        throw Error("unsupported claim");
      }
      const lower = text.toLowerCase();
      if (fact.assessment === "close" && /mistake|wrong|incorrect|should have|错误|失误|必须/.test(lower)) {
        throw Error("uncertainty");
      }
      for (const [action, words] of Object.entries(aliases)) {
        if (action !== fact.actual_action && action !== fact.alternative_action &&
            words.some(word => lower.includes(word))) throw Error("unsupported action");
      }
      texts[key] = text.trim();
    }
    seen.add(id);
    output.push({
      decision_id: id, actual_action: fact.actual_action,
      alternative_action: fact.alternative_action, assessment: fact.assessment, ...texts,
    });
  }
  return { items: output };
}
