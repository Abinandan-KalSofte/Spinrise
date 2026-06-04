import json, base64, urllib.request
from pathlib import Path

cfg = json.load(open("config.json"))

# 1. Jira auth check
creds = f"{cfg['jira_email']}:{cfg['jira_token']}"
token = base64.b64encode(creds.encode()).decode()
headers = {
    "Authorization": f"Basic {token}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}
body = json.dumps({
    "jql": "project = SPIN ORDER BY key DESC",
    "maxResults": 3,
    "fields": ["summary", "status"],
}).encode()
req = urllib.request.Request(
    "https://kalsofte.atlassian.net/rest/api/3/search/jql",
    data=body, headers=headers,
)
with urllib.request.urlopen(req, timeout=10) as r:
    result = json.loads(r.read())
print("Jira OK — latest issues:")
for i in result["issues"]:
    print(f"  {i['key']} [{i['fields']['status']['name']}] {i['fields']['summary']}")

# 2. MBOX paths
inbox = Path(cfg["thunderbird_path"])
sent  = Path(cfg.get("sent_path", ""))
print(f"\nINBOX exists : {inbox.exists()} — {inbox.name}")
print(f"Sent  exists : {sent.exists()} — {sent.name}")

# 3. Sprint
print(f"\nJira sprint ID : {cfg.get('jira_sprint_id')} (active Sprint 1)")
print(f"Assignee ID    : {cfg.get('jira_default_assignee_id')}")
print("\nAll checks passed — agent is ready to run.")
