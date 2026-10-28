#!/usr/bin/env python3
import json
import os
import plistlib
import sys
from datetime import datetime

PLIST = os.path.expanduser("~/Library/Preferences/com.yijianrili.app.plist")

HISTORY_KEY = "historyEntriesData"
STATUS_KEY = "occurrenceStatusData"


APPLE_EPOCH_OFFSET = 978307200


def human_day(ts):
    return datetime.fromtimestamp(ts + APPLE_EPOCH_OFFSET).strftime("%Y-%m-%d")


def load_plist(path):
    if not os.path.exists(path):
        print(f"找不到偏好文件: {path}")
        sys.exit(1)
    with open(path, "rb") as handle:
        return plistlib.load(handle)


def parse_json(raw):
    if not raw:
        return [], "empty"
    try:
        return json.loads(raw), "ok"
    except json.JSONDecodeError as error:
        return None, f"corrupt: {error}"


def report_history(store):
    raw = store.get(HISTORY_KEY, "")
    entries, state = parse_json(raw)
    print(f"\n历史记录 ({HISTORY_KEY})")
    print(f"  原始长度: {len(raw)} 字符, 状态: {state}")
    if entries is None:
        print("  ⚠️ 无法解码。下一次写入会以空列表为基线覆盖，全部条目会永久丢失。")
        return entries

    usable = 0
    broken = 0
    for index, entry in enumerate(entries):
        ids = entry.get("createdEventIdentifiers") or []
        review_dates = [human_day(ts) for ts in (entry.get("reviewDates") or [])]
        title = (entry.get("title") or "")[:30]
        kind = entry.get("type")
        if ids:
            usable += 1
            mark = "可用"
        else:
            broken += 1
            mark = "空 id"
        print(f"  [{index:2}] {title:32} {kind:7} ids={len(ids)} {mark:6} {','.join(review_dates)}")
    print(f"  合计 {len(entries)} 条：可用 {usable}，空 id {broken}")

    if len(entries) > 20:
        print(f"  ⚠️ 超过上限 20 条，写入时会被截断到 20（静默丢弃 {len(entries) - 20} 条）")
    return entries


def report_status(store, entries):
    raw = store.get(STATUS_KEY, "{}")
    statuses, state = parse_json(raw)
    print(f"\n完成/跳过标记 ({STATUS_KEY})")
    print(f"  状态: {state}")
    if statuses is None:
        print("  ⚠️ 无法解码。")
        return

    known = set()
    for entry in entries or []:
        known.update(entry.get("createdEventIdentifiers") or [])

    marked = {key: value for key, value in statuses.items() if value and value != "unmarked"}
    series = [key for key in marked if key.startswith("series:")]
    unmatched = [key for key in marked if not key.startswith("series:") and key not in known]
    print(
        f"  条目数: {len(marked)}，新格式（series:）{len(series)} 条，"
        f"旧格式 {len(marked) - len(series)} 条"
    )
    if series:
        print("  新格式键挂在系列身份上，日历同步重分配 id 后仍然有效。")
    if unmatched:
        print(f"  其中 {len(unmatched)} 条旧键已无法对应任何历史记录里的 id：")
        print("  它们指向早已失效的事件 id，不会自动清理，但也不影响新操作。")
        for key in unmatched[:5]:
            tail = key.split(":")[-1]
            print(f"    {marked[key]:8} {tail[:16]}")
        if len(unmatched) > 5:
            print(f"    ... 另有 {len(unmatched) - 5} 条")
    print("  判据：出现 series: 前缀说明新标记是安全的；旧键数量只增不减才是问题。")


def report_json_keys(store):
    print("\n其它 JSON 键")
    for key in sorted(store):
        if not key.endswith("Data"):
            continue
        if key in (HISTORY_KEY, STATUS_KEY):
            continue
        raw = store[key]
        if isinstance(raw, bytes):
            continue
        _, state = parse_json(raw)
        flag = "ok" if state == "ok" else state
        print(f"  {key:34} {len(raw):6} 字符  {flag}")


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else PLIST
    store = load_plist(path)
    print(f"偏好文件: {path}")
    entries = report_history(store)
    report_status(store, entries)
    report_json_keys(store)


if __name__ == "__main__":
    main()
