---
description: Run the test suite with nextest and fix failures
---

Run `cargo nextest run` in the current project.

If any tests fail, investigate the root cause and fix the code — not the test,
unless the test itself is wrong (call that out explicitly). Re-run until the
suite is green, then summarise each failure and how you fixed it.
