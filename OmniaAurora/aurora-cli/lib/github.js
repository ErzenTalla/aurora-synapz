const GITHUB_API = 'https://api.github.com';
const DEFAULT_REPOS = ['ErzenTalla/aurora-synapz', 'ErzenTalla/alpinetechwebsite'];
const ACTIVITY_WINDOW_MS = 48 * 60 * 60 * 1000;

function getTrackedRepos() {
  return (process.env.GITHUB_REPOS || DEFAULT_REPOS.join(','))
    .split(',')
    .map((r) => r.trim())
    .filter(Boolean);
}

async function ghFetch(path) {
  const res = await fetch(`${GITHUB_API}${path}`, {
    headers: {
      Authorization: `Bearer ${process.env.GITHUB_TOKEN}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    },
  });
  if (!res.ok) throw new Error(`GitHub fetch failed (${path}): ${res.status}`);
  return await res.json();
}

export async function fetchRepoActivity(repo) {
  const since = new Date(Date.now() - ACTIVITY_WINDOW_MS).toISOString();
  const [commits, pulls, issues] = await Promise.all([
    ghFetch(`/repos/${repo}/commits?since=${since}&per_page=10`).catch(() => []),
    ghFetch(`/repos/${repo}/pulls?state=open&per_page=10`).catch(() => []),
    ghFetch(`/repos/${repo}/issues?state=open&per_page=10`).catch(() => []),
  ]);

  return {
    repo,
    commits: commits.map((c) => ({
      message: c.commit.message.split('\n')[0],
      date: c.commit.author?.date,
    })),
    pulls: pulls.map((p) => ({ number: p.number, title: p.title, draft: p.draft })),
    // The issues endpoint also returns PRs — filter those out to avoid double-counting.
    issues: issues.filter((i) => !i.pull_request).map((i) => ({ number: i.number, title: i.title })),
  };
}

export function formatGithubContext(repoActivities) {
  const blocks = repoActivities.map(({ repo, commits, pulls, issues }) => {
    const commitLines = commits.length
      ? commits.map((c) => `  - ${c.message}`).join('\n')
      : '  (no commits in last 48h)';
    const pullLines = pulls.length
      ? pulls.map((p) => `  - #${p.number} ${p.title}${p.draft ? ' (draft)' : ''}`).join('\n')
      : '  (none open)';
    const issueLines = issues.length
      ? issues.map((i) => `  - #${i.number} ${i.title}`).join('\n')
      : '  (none open)';
    return `${repo}:\n  Recent commits (48h):\n${commitLines}\n  Open PRs:\n${pullLines}\n  Open issues:\n${issueLines}`;
  });
  return `PROJECT ACTIVITY (GitHub):\n${blocks.join('\n\n')}`;
}

export async function getProjectContext() {
  if (!process.env.GITHUB_TOKEN) return '';
  const repos = getTrackedRepos();
  const activities = await Promise.all(repos.map(fetchRepoActivity));
  return formatGithubContext(activities);
}
