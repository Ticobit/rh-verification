# Challenge export from two build directories

Step 1 of the riemann-hypothesis README, run twice on one machine at two different absolute paths.

| Run | Build directory | sha256 of challenge.export | Bytes | Lines | vs published sha256 | sha256 of Challenge.olean |
| --- | --- | --- | --- | --- | --- | --- |
| A | `/Users/ticobit/rh-export-test/a/riemann-hypothesis` | `bd484ac9886a96f26b1d9a7a59ebd45b7a70d102c015d4f31f9302bbdd6ab2b9` | 350862311 | 6495712 | identical | `4b46871703f2560006ab375805dea703bec9af2577d01e492106b61c852692d6` |
| B | `/tmp/rh-export-test-b-501/a/much/longer/build/directory/riemann-hypothesis` | `bd484ac9886a96f26b1d9a7a59ebd45b7a70d102c015d4f31f9302bbdd6ab2b9` | 350862311 | 6495712 | identical | `4b46871703f2560006ab375805dea703bec9af2577d01e492106b61c852692d6` |

Published sha256 (README and CI of the repository): `bd484ac9886a96f26b1d9a7a59ebd45b7a70d102c015d4f31f9302bbdd6ab2b9`

| Field | Value |
| --- | --- |
| Date (UTC) | 2026-11-21T06:21:40Z |
| Repository commit | 4286c9ca372a512a43eb66262cf87cbb814c0038 |
| Lean | Lean (version 4.33.1, arm64-apple-darwin24.6.0, commit 819816b2e0a3bf405af45ae5c7af2491d8f5bee6, Release) |
| lean4export | tag v4.33.0, commit 15f6055e299ad5b89345e533cc2192f4cc00f659 |
| Machine | Apple M6, 24 GB RAM |
| OS | macOS 27.2.1 (arm64) |

Scope: this is the challenge export (five statements with `sorry`), not the solution export.
Not sandboxed. Full output in export_test.log.
