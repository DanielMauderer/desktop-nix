---
description: Run clippy across all targets and fix the warnings
---

Run `cargo clippy --all-targets --all-features` in the current project.

For each warning, fix it at the source — don't silence it with `#[allow(...)]`
unless the lint is genuinely a false positive (and say so if you do). Re-run
clippy until it reports no warnings, then give a short summary of what changed.
