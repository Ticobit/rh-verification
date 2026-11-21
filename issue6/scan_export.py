#!/usr/bin/env python3
"""Byte-level scan of a Susz export for path-like strings and for `sorryAx`.

Susz stores name components and string literals as raw UTF-8, so a byte search
finds them. Controls (names that must be present) show the search is sensitive.
Usage: scan_export.py FILE.susz OUT.json   (run again until it reports complete=True)
"""
import json, sys, time

PATTERNS = {
    "controls": [b"propext", b"Classical", b"choice", b"Quot", b"sound",
                 b"riemannHypothesis", b"RiemannHypothesis"],
    "axiom_names": [b"sorryAx", b"sorry", b"ofReduceBool", b"trustCompiler", b"native_decide"],
    "paths": [b"/Users/", b"/home/", b"/root/", b"/tmp/", b"/private/", b"/mnt/",
              b"/var/", b"/opt/", b"/nix/", b"/data/", b"/scratch/", b"/build/",
              b"/workspace/", b"/runner/", b"C:\\", b".lean", b".lake", b".olean"],
}
ALL = [p for g in PATTERNS.values() for p in g]
MAXLEN = max(len(p) for p in ALL)
CHUNK = 64 * 1024 * 1024

def main(path, out, budget=140.0):
    """Resumable: each call scans for `budget` seconds and saves its state in OUT."""
    import os, base64
    size = os.path.getsize(path)
    st = {"pos": 0, "tail": "", "counts": {}, "samples": {}, "seconds": 0.0}
    if os.path.exists(out):
        st = json.load(open(out))["state"]
    counts = {p: st["counts"].get(p.decode(), 0) for p in ALL}
    samples = {p: st["samples"].get(p.decode(), []) for p in ALL}
    pos = st["pos"]
    tail = base64.b64decode(st["tail"])
    t0 = time.time()
    with open(path, "rb") as f:
        f.seek(pos)
        while time.time() - t0 < budget:
            buf = f.read(CHUNK)
            if not buf:
                break
            data = tail + buf
            base = pos - len(tail)
            for p in ALL:
                i = data.find(p)
                while i != -1:
                    # count only matches that end inside the new bytes (no double count)
                    if i + len(p) > len(tail):
                        counts[p] += 1
                        if len(samples[p]) < 5:
                            ctx = data[max(0, i - 24): i + len(p) + 40]
                            samples[p].append({"offset": base + i,
                                               "context": ctx.decode("utf-8", "replace")})
                    i = data.find(p, i + 1)
            pos += len(buf)
            tail = data[-(MAXLEN - 1):]
    secs = round(st["seconds"] + time.time() - t0, 1)
    res = {
        "file": path.split("/")[-1], "bytes_total": size, "bytes_scanned": pos,
        "complete": pos == size, "seconds": secs,
        "groups": {g: {p.decode(): counts[p] for p in ps} for g, ps in PATTERNS.items()},
        "samples": {p.decode(): samples[p] for p in ALL if samples[p]},
        "state": {"pos": pos, "tail": base64.b64encode(tail).decode(), "seconds": secs,
                  "counts": {p.decode(): counts[p] for p in ALL},
                  "samples": {p.decode(): samples[p] for p in ALL}},
    }
    json.dump(res, open(out, "w"), indent=1, ensure_ascii=False)
    print("scanned %d / %d bytes (%.1f%%), complete=%s" % (pos, size, 100.0 * pos / size, pos == size))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
