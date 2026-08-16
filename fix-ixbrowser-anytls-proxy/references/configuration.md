# iXBrowser AnyTLS bridge configuration

## Intended topology

Use this topology when an iXBrowser profile's own SOCKS5 proxy fails only while Clash routes the browser through a particular AnyTLS provider:

```text
iXBrowser profile
  -> Clash process-path rule
  -> compatible SOCKS5 bridge
  -> proxy configured inside iXBrowser
  -> destination website
```

The bridge carries the nested SOCKS5 connection. The final public exit IP should remain the proxy configured in iXBrowser.

## Information to collect

Collect these values at runtime. Keep them out of skill files, Git history, screenshots, and chat transcripts whenever possible.

- Bridge proxy hostname or IP
- Bridge proxy port
- Bridge username and password, if required
- iXBrowser proxy hostname or IP for optional fallback matching
- Clash Verge Rev profile and enhancement files currently in use

## Clash Verge Rev enhancement form

In the proxy enhancement, prepend the bridge proxy:

```yaml
prepend:
  - name: iX-SOCKS-bridge
    type: socks5
    server: BRIDGE_PROXY_HOST
    port: BRIDGE_PROXY_PORT
    username: BRIDGE_USERNAME
    password: BRIDGE_PASSWORD
```

Omit `username` and `password` when the bridge does not require authentication.

In the rules enhancement, prepend the process rule:

```yaml
prepend:
  - PROCESS-PATH-REGEX,.*ixBrowser-Resources.*Chromium.*,iX-SOCKS-bridge
```

Optional fixed-destination fallback:

```yaml
prepend:
  - IP-CIDR,IX_PROXY_IP/32,iX-SOCKS-bridge,no-resolve
```

Use the IP fallback only when process matching cannot be made reliable. It affects every local application connecting to that exact address.

Some generic Clash Merge configurations use these keys instead:

```yaml
prepend-proxies:
  - name: iX-SOCKS-bridge
    type: socks5
    server: BRIDGE_PROXY_HOST
    port: BRIDGE_PROXY_PORT
    username: BRIDGE_USERNAME
    password: BRIDGE_PASSWORD

prepend-rules:
  - PROCESS-PATH-REGEX,.*ixBrowser-Resources.*Chromium.*,iX-SOCKS-bridge
```

Do not mix the two syntaxes. Follow the enhancement type and examples shown by the installed Clash Verge Rev version.

## Safe application sequence

1. Locate the active profile in Clash Verge Rev and identify its proxy and rules enhancements.
2. Copy each file before editing:

```bash
stamp=$(date +%Y%m%d-%H%M%S)
cp -p "$target_file" "$target_file.codex-backup-$stamp"
```

3. Add the bridge and process rule to the persistent enhancement files.
4. Confirm the process rule appears before `MATCH` in the merged configuration.
5. Validate the merged mihomo configuration with the binary bundled in Clash Verge Rev.
6. Reload the active configuration and close existing iXBrowser connections.
7. Restart only the affected iXBrowser profile if necessary.

Do not overwrite the whole enhancement file when a targeted edit is sufficient.

## Diagnostics

Check the runtime configuration through the local mihomo controller when available:

```bash
curl --silent --show-error --max-time 5 \
  --unix-socket /tmp/verge/verge-mihomo.sock \
  http://127.0.0.1/configs
```

Inspect iXBrowser connections:

```bash
curl --silent --show-error --max-time 5 \
  --unix-socket /tmp/verge/verge-mihomo.sock \
  http://127.0.0.1/connections |
jq '.connections[]
  | select((.metadata.processPath // "") | test("ixBrowser-Resources.*Chromium"; "i"))
  | {
      destination: ((.metadata.destinationIP // .metadata.host) + ":" + (.metadata.destinationPort | tostring)),
      processPath: .metadata.processPath,
      rule: .rule,
      rulePayload: .rulePayload,
      chains: .chains
    }'
```

Test a SOCKS5 proxy without exposing the password in shell history. Prefer an interactive secret source or a protected temporary credential mechanism supported by the environment:

```bash
curl --socks5-hostname 'HOST:PORT' https://api.ipify.org
```

If authenticated testing is necessary, do not paste a real credential into committed scripts or visible command output.

## Verification checklist

- The bridge proxy is reachable and healthy.
- The iXBrowser helper's `processPath` matches the narrow regex.
- `rule` or `rulePayload` identifies the process-path rule.
- The first live chain hop is `iX-SOCKS-bridge`.
- ChatGPT loads in the affected profile.
- The final public IP matches the profile's intended proxy exit.
- Unrelated Chrome or Chromium apps are not routed through the bridge.
- A newly selected iXBrowser proxy works without adding another Clash rule.

## Troubleshooting

### `ERR_SOCKS_CONNECTION_FAILED` remains

- Verify the bridge itself supports outbound TCP to the iXBrowser proxy address and port.
- Check that the enhancement was enabled and merged, not merely saved.
- Check rule order and remove stale connections before retesting.
- Inspect the actual `--proxy-server` argument of the running iXBrowser Chromium process.
- Try a different bridge provider if only one upstream rejects nested SOCKS traffic.

### iXBrowser cannot log in after changing its proxy

Restore the profile's original proxy record if the user explicitly changed it. Prefer solving the upstream path in Clash; proxy replacement can change region, fingerprint consistency, allowlists, or account risk signals.

### ChatGPT returns 403 or a verification page

The SOCKS handshake and route may already be working. Check the final exit region and IP reputation, then test the same exit outside iXBrowser. Do not keep modifying Clash rules solely because of an application-layer 403.

### The toolbar shows an unexpected proxy

Treat the running Chromium command line and live Clash metadata as authoritative. The UI label can lag behind the process state.

## User-facing setup summary

Explain the fix in this order:

1. Prepare one compatible SOCKS5 bridge.
2. Add it globally to Clash as `iX-SOCKS-bridge`.
3. Add the macOS iXBrowser process-path rule at the top of Clash rules.
4. Reload Clash and restart the affected iXBrowser profile.
5. Verify the live rule, chain, and final exit IP.

Emphasize that users continue managing their actual per-profile proxies in iXBrowser; the global Clash rule only supplies a compatible transport path.

## Upstream documentation

- Mihomo routing rules: <https://wiki.metacubex.one/en/config/rules/>
- Mihomo proxy fields: <https://wiki.metacubex.one/en/config/proxies/>
- Clash Verge Rev Merge: <https://clashvergerev.com/en/guide/merge>
- Clash Verge Rev User Guide: <https://clashvergerev.com/en/guide/>
