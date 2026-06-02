#!/usr/bin/env bash
set -u

SUPPORT_DIR="${CLASH_VERGE_DIR:-$HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev}"
SOCKET="${MIHOMO_SOCKET:-/tmp/verge/verge-mihomo.sock}"
CONFIG="$SUPPORT_DIR/clash-verge.yaml"

section() {
  printf '\n== %s ==\n' "$1"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

section "Environment"
date
printf 'support_dir: %s\n' "$SUPPORT_DIR"
printf 'config: %s\n' "$CONFIG"
printf 'socket: %s\n' "$SOCKET"

section "WeChat Processes"
if have rg; then
  ps aux | rg -i 'WeChat|xinWeChat|微信' || true
else
  ps aux | grep -Ei 'WeChat|xinWeChat|微信' | grep -v grep || true
fi

section "System Proxy"
scutil --proxy 2>/dev/null || true

section "DNS Samples"
for name in short.weixin.qq.com long.weixin.qq.com file.wx.qq.com servicewechat.com google.com cloudflare.com; do
  printf '\n-- %s A --\n' "$name"
  dig +short A "$name" 2>/dev/null | sed -n '1,8p' || true
  printf -- '-- %s AAAA --\n' "$name"
  dig +short AAAA "$name" 2>/dev/null | sed -n '1,8p' || true
done

section "Route Summary"
netstat -rn -f inet 2>/dev/null | sed -n '1,80p' || true
printf '\n-- IPv6 selected --\n'
netstat -rn -f inet6 2>/dev/null | grep -E 'default|utun|fdfe:dcba|240e:' | sed -n '1,120p' || true

section "Clash Verge Files"
if [ -d "$SUPPORT_DIR" ]; then
  ls -la "$SUPPORT_DIR" | sed -n '1,120p'
  printf '\n-- profiles.yaml --\n'
  sed -n '1,180p' "$SUPPORT_DIR/profiles.yaml" 2>/dev/null || true
else
  printf 'support directory not found\n'
fi

section "Mihomo Config"
if [ -S "$SOCKET" ] && have curl && have jq; then
  curl --silent --show-error --max-time 5 --unix-socket "$SOCKET" http://127.0.0.1/configs |
    jq '{mode, ipv6, tun: .tun}' || true
else
  printf 'controller socket or curl/jq unavailable\n'
fi

section "WeChat Connections"
if [ -S "$SOCKET" ] && have curl && have jq; then
  curl --silent --show-error --max-time 5 --unix-socket "$SOCKET" http://127.0.0.1/connections |
    jq -r '.connections[]
      | select((.metadata.host // "" | test("weixin|wechat|wx\\.qq|qq\\.com|tencent|qpic|gtimg|servicewechat|weixinbridge"; "i"))
        or (.metadata.processPath // "" | test("WeChat|xinWeChat"; "i"))
        or (.metadata.process // "" | test("WeChat|xinWeChat"; "i")))
      | [.metadata.host, .metadata.destinationIP, .metadata.destinationPort, .metadata.network, .metadata.type, .rule, (.chains|join(" > ")), .metadata.process, .metadata.processPath]
      | @tsv' | sed -n '1,160p' || true
else
  printf 'controller socket or curl/jq unavailable\n'
fi

section "Config Snippets"
if [ -f "$CONFIG" ]; then
  if have rg; then
    rg -n '^(ipv6:|tun:|dns:|  ipv6:|  enhanced-mode|  fake-ip-filter|  route-exclude-address|rules:)|PROCESS-NAME,WeChat|servicewechat|weixin|qq\\.com|tencent|qpic|gtimg' "$CONFIG" || true
  else
    grep -En '^(ipv6:|tun:|dns:|  ipv6:|  enhanced-mode|  fake-ip-filter|  route-exclude-address|rules:)|PROCESS-NAME,WeChat|servicewechat|weixin|qq\\.com|tencent|qpic|gtimg' "$CONFIG" || true
  fi
else
  printf 'config not found\n'
fi
