---
name: fix-ixbrowser-anytls-proxy
description: Diagnose and repair iXBrowser SOCKS5 proxy failures on macOS after Clash Verge Rev or mihomo nodes change from Shadowsocks (SS) to AnyTLS. Use when iXBrowser shows ERR_SOCKS_CONNECTION_FAILED, ChatGPT works through other providers but not one AnyTLS provider, changing the browser proxy breaks profile login, or a safe Clash-side bridge is needed without altering iXBrowser proxy settings.
---

# Fix iXBrowser AnyTLS Proxy

## Overview

Diagnose nested-proxy failures between iXBrowser and Clash/mihomo, then route only iXBrowser's Chromium helper through a compatible SOCKS5 bridge. Keep the proxy stored in each iXBrowser profile unchanged unless the user explicitly authorizes changing it.

Read [references/configuration.md](references/configuration.md) before applying a fix. It contains the configuration forms, verification checks, rollback steps, and user-facing instructions.

## Guardrails

- Treat proxy server addresses, usernames, passwords, and subscription URLs as secrets. Never print or commit real credentials; redact them in logs and examples.
- Diagnose only when the user asks for diagnosis. Make changes only when the user asks to fix or configure the system.
- Modify Clash rather than iXBrowser by default. Do not open, replace, test-save, or delete an iXBrowser profile proxy without explicit permission.
- Back up every Clash file immediately before editing it. Preserve unrelated rules and profile settings.
- Prefer persistent Clash Verge enhancement files over editing only generated runtime files.
- Do not add `skip-cert-verify`, disable TLS verification, or weaken browser security.
- Do not use a broad `PROCESS-NAME,Chromium` rule; it can capture unrelated Chromium applications.

## Workflow

1. Confirm the failure boundary.
   - Record the exact browser error.
   - Establish whether the same iXBrowser proxy works outside the affected AnyTLS route.
   - If ChatGPT reaches a login challenge or HTTP 403 page, the SOCKS connection is working; investigate exit-IP reputation or account state instead.

2. Identify the actual iXBrowser process and proxy.
   - Inspect the iXBrowser Chromium command line for `--proxy-server` instead of trusting a possibly stale toolbar label.
   - On macOS, target the helper path with `PROCESS-PATH-REGEX,.*ixBrowser-Resources.*Chromium.*,...`.
   - Query mihomo's controller through `/tmp/verge/verge-mihomo.sock` when available and inspect `processPath`, `rule`, `rulePayload`, and `chains`.

3. Distinguish credentials from proxy chaining.
   - Test the configured proxy with `curl --socks5-hostname` using secrets supplied at runtime.
   - Compare direct connectivity with connectivity captured by the affected AnyTLS node.
   - A SOCKS greeting that times out only through one provider indicates an incompatible or blocked nested proxy path, not necessarily a bad iXBrowser password.

4. Apply the narrow bridge fix.
   - Add a compatible SOCKS5 proxy named `iX-SOCKS-bridge` to Clash.
   - Prepend the iXBrowser process-path rule so it runs before broad rules and `MATCH`.
   - Add a `/32` destination-IP rule only as a fallback when process metadata is unavailable or unreliable.
   - Reload Clash and close old iXBrowser connections so new sessions use the rule.

5. Validate end to end.
   - Confirm the live connection matches the process-path rule and begins with `iX-SOCKS-bridge` in `chains`.
   - Open ChatGPT in the intended iXBrowser profile.
   - Confirm the final public exit IP is still the proxy configured inside iXBrowser, not the bridge proxy.
   - Test a second iXBrowser profile to verify the global Clash rule works without per-profile edits.

6. Roll back if validation fails.
   - Restore the backed-up Clash files, reload mihomo, and close stale connections.
   - Leave all iXBrowser proxy records untouched.

## Outcome Reporting

Tell the user:

- Whether the fault was credentials, reachability, rule ordering, AnyTLS proxy chaining, or exit-IP reputation.
- Exactly which Clash files or enhancement entries changed.
- Whether iXBrowser settings were left unchanged.
- Which live rule and chain handled the verified request.
- Any bridge expiry, traffic, or concurrency limits the user must maintain.
