#!/usr/bin/env python3
"""Streaming scan of a lean4export ndjson file (format 3.1.0).

Reads the file line by line and reports: record counts by kind, the axiom
declarations with their names resolved, and every Name string and string
literal that contains '/' or '\\'. Memory use is small: only the Name table
is kept.

Usage: ndjson_scan.py FILE.ndjson OUT.json
"""
import json, os, re, sys, time

KIND = re.compile(rb'\{"(?:i[eln]":\d+,")?(\w+)":')
DECLS = {b"axiom", b"def", b"thm", b"opaque", b"quot", b"inductive"}
WATCH = ["sorryAx", "sorry", "ofReduceBool", "reduceBool", "trustCompiler", "native_decide"]


def main(path, out):
    t0 = time.time()
    kinds = {}
    names = {}                      # index -> (prefix index, component)
    uniq = set()
    str_records = 0
    slash_names, slash_lits = [], []
    n_slash_names = n_slash_lits = n_lits = 0
    watch = {w: 0 for w in WATCH}
    sorry_substring = 0
    axioms = []
    flags = {'"isUnsafe":true': 0, '"safety":"unsafe"': 0, '"safety":"partial"': 0}
    meta = None
    unparsed = 0
    lines = 0
    with open(path, "rb", buffering=1 << 24) as f:
        for line in f:
            lines += 1
            if lines % 50_000_000 == 0:
                print("  %d M lines, %.0f s" % (lines // 1_000_000, time.time() - t0),
                      file=sys.stderr, flush=True)
            m = KIND.match(line)
            if not m:
                unparsed += 1
                continue
            k = m.group(1)
            kinds[k] = kinds.get(k, 0) + 1
            if k == b"str":
                o = json.loads(line)
                s = o["str"]["str"]
                names[o["in"]] = (o["str"]["pre"], s)
                str_records += 1
                uniq.add(s)
                if s in watch:
                    watch[s] += 1
                if "sorry" in s:
                    sorry_substring += 1
                if "/" in s or "\\" in s:
                    n_slash_names += 1
                    if len(slash_names) < 20:
                        slash_names.append(s)
            elif k == b"num":
                o = json.loads(line)
                names[o["in"]] = (o["num"]["pre"], o["num"]["i"])
            elif k == b"strVal":
                n_lits += 1
                s = json.loads(line)["strVal"]
                if "/" in s or "\\" in s:
                    n_slash_lits += 1
                    if len(slash_lits) < 20:
                        slash_lits.append(s[:200])
            elif k in DECLS:
                for fl in flags:
                    if fl.encode() in line:
                        flags[fl] += 1
                if k == b"axiom":
                    axioms.append(json.loads(line)["axiom"])
            elif k == b"meta":
                meta = json.loads(line)["meta"]

    def resolve(i):
        parts, seen = [], 0
        while i in names and seen < 1000:
            pre, comp = names[i]
            parts.append(str(comp))
            i = pre
            seen += 1
        return ".".join(reversed(parts)) or "[anonymous or unresolved %s]" % i

    res = {
        "file": os.path.basename(path),
        "bytes": os.path.getsize(path),
        "lines": lines,
        "lines_not_recognised": unparsed,
        "meta": meta,
        "records_by_kind": {k.decode(): v for k, v in sorted(kinds.items())},
        "axiom_declarations": [{"name": resolve(a["name"]), "isUnsafe": a.get("isUnsafe")}
                               for a in axioms],
        "unsafe_or_partial_flags_in_declarations": flags,
        "name_strings": {"records": str_records, "unique": len(uniq),
                         "containing_slash_or_backslash": n_slash_names,
                         "samples": slash_names},
        "string_literals": {"records": n_lits,
                            "containing_slash_or_backslash": n_slash_lits,
                            "samples": slash_lits},
        "name_components_equal_to": watch,
        "name_components_containing_sorry": sorry_substring,
        "seconds": round(time.time() - t0, 1),
    }
    json.dump(res, open(out, "w"), indent=1, ensure_ascii=False)
    print("%s: %d lines, %d bytes" % (res["file"], lines, res["bytes"]))
    print("  axiom declarations: %s" % ", ".join(a["name"] for a in res["axiom_declarations"]))
    print("  Name strings: %d records, %d unique, %d with / or \\" %
          (str_records, len(uniq), n_slash_names))
    print("  string literals: %d, %d with / or \\" % (n_lits, n_slash_lits))
    print("  components equal to: %s" % watch)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
