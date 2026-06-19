import { getJSON, saveJSON } from './store.js';

const TOKENS_PATHNAME = 'google-tokens.json';
const TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';
export const REDIRECT_URI = 'https://omnia-aurora.vercel.app/api/google-auth-callback';
export const OAUTH_SCOPES = [
  'https://www.googleapis.com/auth/gmail.readonly',
  'https://www.googleapis.com/auth/calendar.readonly',
  'https://www.googleapis.com/auth/userinfo.email',
].join(' ');

async function requestToken(params) {
  const res = await fetch(TOKEN_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(params),
  });
  if (!res.ok) throw new Error(`Google token request failed: ${res.status} ${await res.text()}`);
  return await res.json();
}

export async function exchangeCodeForTokens(code) {
  const data = await requestToken({
    code,
    client_id: process.env.GOOGLE_CLIENT_ID,
    client_secret: process.env.GOOGLE_CLIENT_SECRET,
    redirect_uri: REDIRECT_URI,
    grant_type: 'authorization_code',
  });
  const tokens = {
    access_token: data.access_token,
    refresh_token: data.refresh_token,
    expiry: Date.now() + data.expires_in * 1000,
  };
  await saveJSON(TOKENS_PATHNAME, tokens);
  return tokens;
}

export async function disconnectGoogle() {
  await saveJSON(TOKENS_PATHNAME, null);
}

export async function getValidAccessToken() {
  const tokens = await getJSON(TOKENS_PATHNAME, null);
  if (!tokens) return null;
  if (Date.now() < tokens.expiry - 60_000) return tokens.access_token;

  const data = await requestToken({
    refresh_token: tokens.refresh_token,
    client_id: process.env.GOOGLE_CLIENT_ID,
    client_secret: process.env.GOOGLE_CLIENT_SECRET,
    grant_type: 'refresh_token',
  });
  const updated = {
    ...tokens,
    access_token: data.access_token,
    expiry: Date.now() + data.expires_in * 1000,
  };
  await saveJSON(TOKENS_PATHNAME, updated);
  return updated.access_token;
}

export async function getConnectedEmail(accessToken) {
  const res = await fetch('https://www.googleapis.com/oauth2/v2/userinfo', {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) return null;
  const data = await res.json();
  return data.email || null;
}

export async function fetchTodaysEvents(accessToken) {
  const now = new Date();
  const startOfDay = new Date(now);
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date(now);
  endOfDay.setHours(23, 59, 59, 999);

  const params = new URLSearchParams({
    timeMin: startOfDay.toISOString(),
    timeMax: endOfDay.toISOString(),
    singleEvents: 'true',
    orderBy: 'startTime',
  });
  const res = await fetch(`https://www.googleapis.com/calendar/v3/calendars/primary/events?${params}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) throw new Error(`Calendar fetch failed: ${res.status}`);
  const data = await res.json();
  return (data.items || []).map((event) => ({
    summary: event.summary || '(no title)',
    start: event.start?.dateTime || event.start?.date,
    end: event.end?.dateTime || event.end?.date,
  }));
}

export async function fetchRecentEmails(accessToken) {
  const listParams = new URLSearchParams({ q: 'newer_than:1d', maxResults: '15' });
  const listRes = await fetch(`https://www.googleapis.com/gmail/v1/users/me/messages?${listParams}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!listRes.ok) throw new Error(`Gmail list failed: ${listRes.status}`);
  const { messages = [] } = await listRes.json();

  const emails = await Promise.all(
    messages.map(async ({ id }) => {
      const params = new URLSearchParams({ format: 'metadata' });
      params.append('metadataHeaders', 'Subject');
      params.append('metadataHeaders', 'From');
      const res = await fetch(`https://www.googleapis.com/gmail/v1/users/me/messages/${id}?${params}`, {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      if (!res.ok) return null;
      const data = await res.json();
      const headers = data.payload?.headers || [];
      const header = (name) => headers.find((h) => h.name === name)?.value || '';
      return { from: header('From'), subject: header('Subject'), snippet: data.snippet || '' };
    })
  );
  return emails.filter(Boolean);
}

export function formatGoogleContext({ events, emails }) {
  const eventLines = events.length
    ? events.map((e) => `- ${e.summary} (${e.start} – ${e.end})`).join('\n')
    : '(none scheduled)';
  const emailLines = emails.length
    ? emails.map((e) => `- From ${e.from}: "${e.subject}" — ${e.snippet}`).join('\n')
    : '(none)';
  return `TODAY'S CALENDAR:\n${eventLines}\n\nRECENT EMAIL (last 24h):\n${emailLines}`;
}

export async function getGoogleContext() {
  const accessToken = await getValidAccessToken();
  if (!accessToken) return '';
  const [events, emails] = await Promise.all([
    fetchTodaysEvents(accessToken),
    fetchRecentEmails(accessToken),
  ]);
  return formatGoogleContext({ events, emails });
}
