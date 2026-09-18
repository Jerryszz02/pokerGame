import type { Fact, Review, ReviewItem } from '../src/protocol';

export const KEY = 'fixture-not-a-real-api-key';
export function input(id = 1): Review {
  const fact: Fact = {
    decision_id: id, actual_action: 'call', actual_amount: 20,
    alternative_action: 'fold', alternative_amount: 0,
    actual_ev_bb: .2, alternative_ev_bb: .3, gap_bb: .1,
    assessment: 'close', sample_count: 32,
  };
  return { analysis_version: 1, locale: 'en', decisions: [fact] };
}
export function item(id = 1): ReviewItem {
  return {
    decision_id: id, actual_action: 'call', alternative_action: 'fold', assessment: 'close',
    explanation: 'The estimates remain close.',
    next_step: 'Review the sampling uncertainty before deciding.',
  };
}
export function envelope(items: unknown = [item()], finishReason = 'stop') {
  return { choices: [{ finish_reason: finishReason, message: { content: JSON.stringify({ items }) } }] };
}
export function providerResponse(id = 1) { return Response.json(envelope([item(id)])); }
