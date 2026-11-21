# rh-verification

An independent re-check, on a desktop Mac, of the Lean export of Levent Alpöge's
proof of the Riemann Hypothesis (announced 2026-11-20), using the
[Gruszka](https://github.com/jasisz/gruszka) kernel.

**Result:** `accepted`, exit code 0, in 197.5 s on a Mac mini (Apple M6, 24 GB RAM)
with 8 workers. Full details in [RECEIPT.md](RECEIPT.md).

## Reproduce

Needs git, curl and a Rust toolchain. Downloads a 5.83 GB file.

```
git clone https://github.com/Ticobit/rh-verification
cd rh-verification
./verify.sh        # or ./verify.sh 4 to use fewer workers and less memory
```

The script builds Gruszka from source, downloads the export, checks its sha256,
runs the checker and writes `RECEIPT.md`.

## What this does and does not show

- It shows that every declaration in the solution export type-checks in a kernel
  implemented independently of Lean's own.
- The input is the Susz repack of `solution.ndjson` (sha256 `5ea74b91…`, from
  <https://math.mit.edu/~drew/grh/>) published by Gruszka's author. I did not
  repack it from the ndjson myself.
- It does not compare the proved statements against the challenge file. That is
  the job of `lake comparator`; see
  <https://github.com/leanprover-community/riemann-hypothesis>.
- It says nothing about understanding the mathematics.

## Scan of the solution export (for riemann-hypothesis issue #6)

`issue6/scan_export.py` does a byte-level scan of the same Susz file
(5,825,045,873 bytes); results are in `issue6/scan_result.json`.

- `sorryAx`, `sorry`, `ofReduceBool`, `trustCompiler`, `native_decide`: 0 occurrences each.
- 18 path-like patterns (`/Users/`, `/home/`, `/tmp/`, `.lean`, `.olean`, ...): 0 occurrences each.
- Controls that must be present are found (`propext` 2, `Quot` 17,585,
  `riemannHypothesis` 1), so the search does see names in this format.

Limits: this is a byte search on a third-party repack, not a parse of the
original ndjson, and it has no positive control for string literals.

## Challenge export from two build directories (issue #6)

`issue6/challenge_export_test.sh` runs step 1 of the riemann-hypothesis README
(the same commands as its CI job) in two clones at different absolute paths.
Result, in `issue6/EXPORT_TEST.md`:

- Both exports have sha256 `bd484ac9…b2b9` (350,862,311 bytes, 6,495,712 lines),
  identical to the sha256 published by the repository's CI, which runs on Linux.
  This run was on macOS arm64.
- `Challenge.olean` has the same sha256 in both directories.

Limits: this is the challenge export, not the solution export; Mathlib's oleans
came from the official cache in both runs; both runs were on one machine and
not sandboxed.

## Notes

The scripts were written with Claude (Anthropic). I ran them and reviewed the output.
