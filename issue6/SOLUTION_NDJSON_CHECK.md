# The scan, repeated on the original MIT export

| Check | Result |
| --- | --- |
| solution.ndjson.zst | 7699933588 bytes, sha256 `61a8938ad5f5e57397c1c0e3b954916af546d9004ade01c3555744a681b05381` (as published) |
| solution.ndjson | 61570595788 bytes, sha256 `5ea74b912147c5c93cc2b6d70cc727cf908df2f62ac6a20480a3fa02f6be244e` (as published) |
| My Susz pack of it | sha256 `a5b17c25c97daf1ab1ed69addc1a0be09f1ccdd122e718c3a7670d9044d7aceb`: byte-identical to `rh-alpoge-5ea74b91.susz`, the file Gruszka checked (`susz pack`, with index) |
| susz | susz 0.1.4 (Susz 1) |
| Date (UTC) | 2026-11-21T08:04:38Z |
| Machine | Apple M6, macOS 27.2.1 |

## Line-by-line scan (`ndjson_scan.py`)

| | challenge.export (control) | solution.ndjson |
| --- | --- | --- |
| Lines | 6,495,712 | 1,080,769,508 |
| Bytes | 350,862,311 | 61,570,595,788 |
| Lines not recognised | 0 | 0 |
| Axiom declarations | 4: `propext`, `Quot.sound`, `Classical.choice`, `sorryAx` | 3: `propext`, `Quot.sound`, `Classical.choice` |
| Declarations (axiom + def + thm + opaque + quot + inductive records) | | 1,468,418 |
| Name strings: records / unique / with `/` or `\` | 183,806 / 30,044 / 0 | 7,125,163 / 916,245 / 0 |
| String literals: records / with `/` or `\` | 95 / 0 | 162 / 0 |
| Name components equal to `sorryAx` | 1 | 0 |
| Declarations flagged unsafe or partial | 0 | 0 |

The control column reproduces the numbers already posted in issue #6 for the
challenge (6,495,712 records, 183,806 strings, 30,044 unique, four axioms, one `sorryAx`).

`susz axioms --all` on my pack reports 1,468,418 declarations and the same three axioms
(`susz_axioms.txt`). Full output: `ndjson_scan_solution.json`, `ndjson_scan_challenge.json`.
