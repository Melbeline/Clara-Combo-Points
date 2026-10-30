import json, os, sys, collections, datetime
root = sys.argv[1]
files = []
for d, _, fs in os.walk(root):
    for f in fs:
        if f.endswith(".jsonl"): files.append(os.path.join(d, f))
tot = collections.defaultdict(lambda: collections.Counter())
seen = set()
first = last = None
main_ts = []
for p in files:
    is_main = os.path.basename(p) == "a40ebf08-b1d3-5823-a679-3c8357a6d5fa.jsonl"
    kind = "main" if is_main else ("workflow" if "/workflows/" in p else "subagent")
    with open(p, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if '"usage"' not in line and not is_main: continue
            try: e = json.loads(line)
            except Exception: continue
            ts = e.get("timestamp")
            if is_main and ts: main_ts.append(ts)
            if e.get("type") != "assistant": continue
            m = e.get("message") or {}
            u = m.get("usage"); mid = m.get("id")
            if not u or not mid: continue
            key = (p if not is_main else "main", mid, e.get("requestId"))
            if (mid, e.get("requestId")) in seen: continue
            seen.add((mid, e.get("requestId")))
            model = m.get("model", "?")
            c = tot[(kind, model)]
            c["msgs"] += 1
            for k in ("input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"):
                c[k] += u.get(k) or 0
            cc = u.get("cache_creation") or {}
            c["cw_5m"] += cc.get("ephemeral_5m_input_tokens") or 0
            c["cw_1h"] += cc.get("ephemeral_1h_input_tokens") or 0
print("files", len(files))
for (kind, model), c in sorted(tot.items()):
    print(kind, model, dict(c))
main_ts.sort()
print("first", main_ts[0], "last", main_ts[-1])
# active time: sum of gaps between consecutive events < 10 min
def parse(t): return datetime.datetime.fromisoformat(t.replace("Z", "+00:00"))
ts = [parse(t) for t in main_ts]
active = datetime.timedelta()
for a, b in zip(ts, ts[1:]):
    g = b - a
    if g < datetime.timedelta(minutes=10): active += g
print("active (gaps<10min)", active)
days = sorted(set(t.date() for t in ts))
print("days with activity", len(days))
