#!/usr/bin/env bash
set -uo pipefail

cd "$(git rev-parse --show-toplevel)"

total=0
isolation_total=0

scan() {
  local label="$1" ext="$2" dir="$3"
  [ -d "$dir" ] || return 0

  local out
  out=$(grep -rn --include="*.$ext" -E '(^[[:space:]]*(//|/\*|\*))|([^:]//)|(/\*.*\*/)' "$dir" 2>/dev/null \
    | grep -v -E 'https?://' || true)

  local count=0
  [ -n "$out" ] && count=$(printf '%s\n' "$out" | wc -l | tr -d ' ')

  if [ "$count" -gt 0 ]; then
    echo "── $label: $count 处"
    printf '%s\n' "$out"
    total=$((total + count))
  else
    echo "── $label: 0 处"
  fi
}

scan "Sources (.swift)" swift Sources
scan "Tests (.swift)"   swift Tests
scan "windows (.cs)"    cs    windows

echo
echo "── 测试隔离"

isolation_out=$(grep -rn --include='*.swift' -E 'ReviewViewModel\(calendar:' Tests 2>/dev/null \
  | grep -v 'defaults:' || true)

isolation_count=0
[ -n "$isolation_out" ] && isolation_count=$(printf '%s\n' "$isolation_out" | wc -l | tr -d ' ')

if [ "$isolation_count" -gt 0 ]; then
  echo "ReviewViewModel 未注入独立 UserDefaults：$isolation_count 处"
  printf '%s\n' "$isolation_out"
  isolation_total=$isolation_count
else
  echo "ReviewViewModel: 0 处"
fi

echo
failed=0
if [ "$total" -gt 0 ]; then
  echo "✗ 共 ${total} 处注释违规。AGENTS.md 硬约束：代码里禁止 /// 、// 、/* */ 、// MARK:"
  failed=1
fi
if [ "$isolation_total" -gt 0 ]; then
  echo "✗ 共 ${isolation_total} 处测试隔离缺失。每个 ReviewViewModel 用例须传 defaults: freshDefaults()，"
  echo "  否则跨用例共享 UserDefaults.standard，只在 CI 上表现为随机失败。"
  failed=1
fi

[ "$failed" -eq 0 ] && echo "✓ 未发现注释违规，测试隔离完整"
exit "$failed"
