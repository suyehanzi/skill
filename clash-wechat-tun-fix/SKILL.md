---
name: clash-wechat-tun-fix
description: Diagnose and fix WeChat for macOS image/file sending failures when text messages work but media fails, especially with Clash Verge Rev or mihomo TUN/fake-ip enabled. Use when Codex needs to inspect local macOS network state, Clash Verge configuration, WeChat media upload routes, fake-ip DNS, IPv6/UDP behavior, and apply reversible Clash rules such as WeChat process DIRECT, Tencent fake-ip exclusions, or selective TUN route exclusions.
---

# Clash WeChat TUN Fix

## Overview

Troubleshoot WeChat media-send failures on macOS where text still sends normally. Prefer reversible Clash/mihomo configuration changes over broad system changes, and validate each layer before moving to the next.

Do not inspect private chat contents. It is acceptable to inspect process lists, DNS results, Clash connection metadata, and file properties for the failed image.

## Quick Diagnosis

Run the bundled diagnostic script when Clash Verge is likely involved:

```bash
bash scripts/diagnose_clash_wechat.sh
```

Key signals:

- `short.weixin.qq.com`, `file.wx.qq.com`, or `servicewechat.com` resolving to `198.18.0.x` means Clash fake-ip is active.
- WeChat connections showing `rule=ProcessName`, `chain=DIRECT`, and `type=Tun` means process DIRECT works but traffic still crosses TUN.
- WeChat UDP connections to IPv6 addresses on ports `443` or `8000` are a common cause of image upload failure.
- If disabling Clash IPv6 fixes media upload, restore global IPv6 later and add selective TUN route exclusions for the observed Tencent IPv6 prefixes.

## Workflow

1. Confirm the symptom.
   - Text messages work.
   - Image/file send fails, usually with a red exclamation mark.
   - Test a small local JPG/PNG to rule out corrupt source files.

2. Check local file and network basics.
   - Use `file`, `sips`, `ls -l@`, and `xattr -l` on the failed image.
   - Check disk space with `df -h`.
   - Check system proxy with `scutil --proxy`.
   - Check WeChat version and process names with `ps aux | rg -i 'WeChat|xinWeChat|微信'`.

3. Check Clash state.
   - Locate Clash Verge config under `~/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev`.
   - Query mihomo via `/tmp/verge/verge-mihomo.sock` when available:

```bash
curl --silent --show-error --max-time 5 \
  --unix-socket /tmp/verge/verge-mihomo.sock \
  http://127.0.0.1/configs | jq '{mode, ipv6, tun}'
```

4. Apply fixes in order, validating after each.

## Fix 1: WeChat Process DIRECT

Add these rules at the top of the active rules prepend/extension and generated config:

```yaml
- PROCESS-NAME,WeChat,DIRECT
- PROCESS-NAME,WeChatAppEx,DIRECT
- PROCESS-NAME,WeChatAppEx Helper,DIRECT
- PROCESS-NAME,WeChatAppEx Helper (Renderer),DIRECT
- PROCESS-NAME,WeChatAppEx Helper (GPU),DIRECT
- PROCESS-NAME,wxutility,DIRECT
- PROCESS-NAME,wxplayer,DIRECT
- PROCESS-NAME,wxocr,DIRECT
```

For Clash Verge Rev, find the active rules extension in `profiles.yaml` under the current profile's `option.rules`; update that file so subscription refreshes preserve the rule. Also sync current generated files such as `clash-verge.yaml` and `clash-verge-check.yaml` when applying immediately.

## Fix 2: Exclude Tencent Domains From Fake-IP

Keep WeChat/Tencent domains on real DNS answers:

```yaml
fake-ip-filter:
  - qq.com
  - '*.qq.com'
  - tencent.com
  - '*.tencent.com'
  - weixin.qq.com
  - '*.weixin.qq.com'
  - wx.qq.com
  - '*.wx.qq.com'
  - wechat.com
  - '*.wechat.com'
  - servicewechat.com
  - '*.servicewechat.com'
  - weixinbridge.com
  - '*.weixinbridge.com'
  - qpic.cn
  - '*.qpic.cn'
  - gtimg.com
  - '*.gtimg.com'
  - qcloud.com
  - '*.qcloud.com'
  - myqcloud.com
  - '*.myqcloud.com'
  - tencent-cloud.com
  - '*.tencent-cloud.com'
```

If the profile uses a script extension, add this programmatically in the script so subscription refreshes preserve it:

```javascript
config.dns = config.dns || {};
const existing = Array.isArray(config.dns["fake-ip-filter"]) ? config.dns["fake-ip-filter"] : [];
config.dns["fake-ip-filter"] = Array.from(new Set([...existing, ...wechatFakeIpFilters]));
```

## Fix 3: IPv6/TUN Upload Failures

If Fix 1 and Fix 2 do not solve the problem, test whether Clash IPv6 is the trigger:

```yaml
ipv6: false
dns:
  ipv6: false
```

If this fixes WeChat image sending, do not leave global IPv6 disabled unless the user prefers stability over granularity. Restore global IPv6 and add selective TUN route exclusions for the Tencent IPv6 prefixes observed in the Clash connection list.

Example:

```yaml
ipv6: true
tun:
  route-exclude-address:
    - 240e:97c:2f::/48
    - 240e:cf:8800::/48
    - 240e:e1:a800::/38
    - 240e:978:d04::/48
dns:
  ipv6: true
```

Derive prefixes from live WeChat connections rather than guessing:

```bash
curl --silent --show-error --max-time 5 \
  --unix-socket /tmp/verge/verge-mihomo.sock \
  http://127.0.0.1/connections |
jq -r '.connections[]
  | select((.metadata.processPath // "" | test("WeChat|xinWeChat"; "i"))
    or (.metadata.process // "" | test("WeChat|xinWeChat"; "i")))
  | [.metadata.destinationIP, .metadata.destinationPort, .metadata.network, .metadata.type, .rule, (.chains|join(" > ")), .metadata.process]
  | @tsv'
```

Avoid relying on `nameserver-policy` with `#disable-ipv6` unless you test it carefully. Some mihomo versions accept the config but return `SERVFAIL` for affected WeChat A records.

## Validation

Always back up changed files before editing:

```bash
ts=$(date +%Y%m%d-%H%M%S)
cp -p "$file" "$file.codex-backup-$ts"
```

Validate and reload mihomo:

```bash
"/Applications/Clash Verge.app/Contents/MacOS/verge-mihomo" -t -f "$config"
curl --silent --show-error --max-time 10 \
  --unix-socket /tmp/verge/verge-mihomo.sock \
  -X PUT 'http://127.0.0.1/configs?force=true' \
  -H 'Content-Type: application/json' \
  --data "{\"path\":\"$config\"}"
```

Flush system DNS and clear old WeChat connections:

```bash
dscacheutil -flushcache
killall -HUP mDNSResponder 2>/dev/null || true
```

Then delete WeChat-related Clash connections through the controller so WeChat reconnects with the new rules.

Verify:

- `dig +short A short.weixin.qq.com` returns real public IPs, not `198.18.0.x`.
- `dig +short A servicewechat.com` returns real public IPs.
- `curl --unix-socket /tmp/verge/verge-mihomo.sock http://127.0.0.1/configs | jq '{ipv6, tun: .tun}'` shows the intended IPv6/TUN settings.
- WeChat can send a small test image after a full WeChat restart.

## Rollback

If a change breaks DNS or proxy behavior, restore the latest `*.codex-backup-*` file and reload mihomo. If selective IPv6 route exclusions fail, return to the known-stable global IPv6-off configuration temporarily, then retry a narrower route exclusion set.
