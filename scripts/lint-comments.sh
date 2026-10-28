#!/usr/bin/env bash
set -uo pipefail

cd "$(git rev-parse --show-toplevel)"

total=0

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
if [ "$total" -gt 0 ]; then
  echo "✗ 共 ${total} 处注释违规。AGENTS.md 硬约束：代码里禁止 /// 、// 、/* */ 、// MARK:"
  exit 1
fi
echo "✓ 未发现注释违规"
