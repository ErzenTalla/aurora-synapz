export const QUESTIONS = [
  ['calendar', "Calendar/today — meetings, appointments, travel?"],
  ['work', "Work — anything pressing, deadlines, leadership topics?"],
  ['alpinetech', "AlpineTech — active work, blockers, decisions?"],
  ['omnia', "Omnia OS / Aurora — anything for this project today?"],
  ['personal', "Personal — family, health, sleep, anything worth flagging?"],
  ['concerns', "Concerns — anything uncertain or weighing on you?"],
];

export function formatTodayContext(answersByKey) {
  const lines = QUESTIONS
    .map(([key]) => [key, (answersByKey[key] || '').trim()])
    .filter(([, value]) => value)
    .map(([key, value]) => `${key.toUpperCase()}: ${value}`);
  return lines.join('\n') || '(nothing given today)';
}
