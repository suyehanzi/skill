---
name: sub2-plus-openwebui
description: Use when diagnosing or fixing chat.suyehanzi.online / Sub2API OpenAI account scheduling, especially keeping Plus/OAuth accounts primary and GPT-Pro as the lowest-priority fallback through openai-main and HK-mihomo-local.
---

# Sub2 Plus OpenWebUI

Use this skill for `chat.suyehanzi.online` conversation failures, Sub2API OpenAI account scheduling, or requests to keep Plus/OAuth accounts primary while leaving GPT-Pro as a fallback.

## Fixed Environment

- SSH host: `suye-hk`
- Sub2API container: `sub2api`
- PostgreSQL container: `sub2api-postgres`
- OpenAI group: `openai-main`, `group_id=2`
- Proxy: `HK-mihomo-local`, `proxy_id=1`
- GPT-Pro: `account_id=1`
- Plus/OAuth accounts: `account_id IN (4,5,6,7,8)`

Do not print, commit, or expose API keys. When a test needs an API key, read it into a shell variable and only print the HTTP status and short response summary.

## Desired State

Priority semantics: lower number means higher priority.

- Plus/OAuth accounts `4,5,6,7,8`:
  - `accounts.status='active'`
  - `accounts.schedulable=true`
  - `accounts.proxy_id=1`
  - `accounts.priority=1`
  - in `account_groups` for `group_id=2`
  - group priorities `1,2,3,4,5`
- GPT-Pro `1`:
  - `accounts.status='active'`
  - `accounts.schedulable=true`
  - `accounts.proxy_id=1`
  - `accounts.priority=10`
  - in `account_groups` for `group_id=2`
  - group priority `10`

This makes Plus/OAuth the normal path and GPT-Pro the lowest-priority fallback.

## Workflow

1. Inspect current state before changing anything.

```powershell
ssh suye-hk @'
cat <<'SQL' | docker exec -i sub2api-postgres psql -U sub2api -d sub2api --csv
SELECT
  ag.account_id,
  a.name,
  a.status,
  a.schedulable,
  a.priority AS account_priority,
  ag.group_id,
  g.name AS group_name,
  ag.priority AS group_priority,
  a.proxy_id,
  a.temp_unschedulable_until,
  a.temp_unschedulable_reason
FROM account_groups ag
JOIN accounts a ON a.id = ag.account_id
JOIN groups g ON g.id = ag.group_id
WHERE ag.group_id = 2
ORDER BY ag.priority, a.priority, ag.account_id;
SQL
'@
```

2. Repair state only when it differs from the desired state.

```powershell
ssh suye-hk @'
cat <<'SQL' | docker exec -i sub2api-postgres psql -U sub2api -d sub2api -v ON_ERROR_STOP=1 --csv
BEGIN;

UPDATE accounts
SET schedulable = TRUE,
    proxy_id = 1,
    priority = 10,
    temp_unschedulable_until = NULL,
    temp_unschedulable_reason = NULL,
    updated_at = NOW()
WHERE id = 1
  AND deleted_at IS NULL;

UPDATE accounts
SET schedulable = TRUE,
    proxy_id = 1,
    priority = 1,
    temp_unschedulable_until = NULL,
    temp_unschedulable_reason = NULL,
    updated_at = NOW()
WHERE id IN (4,5,6,7,8)
  AND deleted_at IS NULL;

INSERT INTO account_groups (account_id, group_id, priority, created_at)
SELECT v.account_id, 2, v.priority, NOW()
FROM (VALUES (4,1),(5,2),(6,3),(7,4),(8,5),(1,10)) AS v(account_id, priority)
WHERE NOT EXISTS (
  SELECT 1
  FROM account_groups ag
  WHERE ag.account_id = v.account_id AND ag.group_id = 2
);

UPDATE account_groups SET priority = 1 WHERE account_id = 4 AND group_id = 2;
UPDATE account_groups SET priority = 2 WHERE account_id = 5 AND group_id = 2;
UPDATE account_groups SET priority = 3 WHERE account_id = 6 AND group_id = 2;
UPDATE account_groups SET priority = 4 WHERE account_id = 7 AND group_id = 2;
UPDATE account_groups SET priority = 5 WHERE account_id = 8 AND group_id = 2;
UPDATE account_groups SET priority = 10 WHERE account_id = 1 AND group_id = 2;

INSERT INTO scheduler_outbox (event_type, account_id, group_id, payload)
VALUES ('full_rebuild', NULL, NULL, NULL);

COMMIT;
SQL
'@
```

3. Validate with server-local chat completion requests.

```powershell
ssh suye-hk @'
set -eu
KEY=$(docker exec sub2api-postgres psql -U sub2api -d sub2api -tA -c "SELECT key FROM api_keys WHERE name='open-webui-admin' AND deleted_at IS NULL ORDER BY id DESC LIMIT 1")
for MODEL in gpt-5.4 gpt-5.5; do
  BODY="{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"stream\":false}"
  STATUS=$(curl -sS -o "/tmp/sub2-$MODEL-test.json" -w '%{http_code}' \
    -H "Authorization: Bearer $KEY" \
    -H 'Content-Type: application/json' \
    --data "$BODY" \
    http://127.0.0.1:8080/v1/chat/completions)
  printf '%s HTTP_STATUS=%s\n' "$MODEL" "$STATUS"
  python3 - "$MODEL" <<'PY'
import sys
from pathlib import Path
model = sys.argv[1]
text = Path(f"/tmp/sub2-{model}-test.json").read_text(errors="replace")
print(text[:500].replace("\n", " "))
PY
done
'@
```

4. Confirm routing in logs.

```powershell
ssh suye-hk "tail -n 160 /opt/sub2api/data/logs/sub2api.log | grep -E 'path.: \"/v1/chat/completions\"|status_code.: (200|502|503)|account_id|upstream_status|account_select_failed' | tail -n 40"
```

Expected result: both test requests return `HTTP_STATUS=200`. The selected `account_id` should normally be one of `4,5,6,7,8`. `account_id=1` is acceptable only when all Plus/OAuth accounts are unavailable.

## Common Failure Patterns

- `no available accounts`: no schedulable account in `openai-main`, cooldowns are active, or scheduler cache is stale.
- Upstream HTML `403`: Plus/OAuth accounts are not using `proxy_id=1`, or OpenAI is rejecting that route. Reapply proxy and clear temporary cooldown.
- Plus accounts exist but are unused: missing `account_groups` rows for `group_id=2`.
- GPT-Pro used too early: Plus/OAuth group priorities or account priorities are not lower than `10`.
