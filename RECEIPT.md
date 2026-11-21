# Gruszka check of the Alpöge RH/GRH Lean export

| Field | Value |
| --- | --- |
| Verdict (last line of stdout) | `accepted` |
| Exit code | 0 |
| Started / finished (UTC) | 2026-11-21T05:35:52Z / 2026-11-21T05:39:10Z |
| Wall time | 197.52 s (CPU: 1418 s user, 40 s sys) |
| Peak memory footprint | 16.8 GiB (18,024,762,784 bytes) |
| Max resident set size | 8.5 GiB (9,165,733,888 bytes) |
| Workers | 8 |
| Machine | Apple M6, 24 GB RAM, 12 cores |
| OS | macOS 27.2.1 (arm64) |
| Checker | https://github.com/jasisz/gruszka @ edd7d47521626f959f23af9a418c32718009d2a9 |
| Rust | rustc 1.100.0 (0ef1bc386 2026-11-09) |
| Input | rh-alpoge-5ea74b91.susz, sha256 a5b17c25c97daf1ab1ed69addc1a0be09f1ccdd122e718c3a7670d9044d7aceb |

## Scope
- Input is the Susz repack published by Gruszka's author of the solution export
  (solution.ndjson, sha256 5ea74b91…, from math.mit.edu/~drew/grh). I did not repack it myself.
- This checks that every declaration in the export type-checks in Gruszka.
  It does not compare the statements against the challenge file; that is what comparator does.
- Logs: run.stdout.log, run.stderr.log.
