---
name: fix-mr-comments
description: >-
  Read the unresolved reviewer comments on the current branch's GitLab merge
  request and fix the small, precisely-described ones yourself — applying each
  fix everywhere the issue occurs — while asking before anything that needs a
  decision and reporting architectural or large changes for a human. Use ONLY
  when the user explicitly asks to address, fix, or work through their MR/PR
  review comments (e.g. "fix the review comments on my PR", "address the
  reviewer feedback", "go through my MR comments and fix what you can"). This is
  a deliberate, command-triggered workflow — never run it on your own just
  because review comments come up in conversation, and never post, reply to, or
  resolve anything on GitLab.
---

# Fix MR Comments

Read the unresolved reviewer comments on the current branch's merge request and
**fix the small, precisely-described ones yourself while asking about decisions
and reporting the big stuff.** The value of this skill is the triage, not the
typing: a confident fix to a comment the reviewer actually wanted _discussed_ is
worse than leaving it for the human. When the comment encodes a choice, ask;
when it implies a design change, report.

Two boundaries are absolute:

- **This skill never writes to GitLab.** No posting comments, no replying to
  threads, no resolving discussions, no approving. It only _reads_ the MR. Every
  GitLab-side action stays the user's to do by hand. The report tells them what
  to resolve or answer.
- **All edits stay in the working tree.** Never commit, never push, never stage
  deliberately for the user. They review the diff and push when ready.

## Repo-specific notes first

This is a generic, personal skill. If the repo has
`.claude/skills/fix-mr-comments/SKILL.md`, it is a repo-tailored version —
personal skills shadow project skills of the same name, so read it and follow it
where it is more specific (e.g. the exact verify command). Also skim the repo's
`CLAUDE.md` for its lint/format/test commands.

## The core idea: triage into three buckets

For each unresolved reviewer comment, decide one of:

- **Auto-fix** — the comment is precisely described, so there is one obvious
  implementation. The sharp test is: **could two competent developers, reading
  this comment, produce materially different code?** If no — there's a single
  obvious change — fix it. This includes behavior-changing fixes when the
  reviewer spelled out exactly what they want (that's the point of the skill; it
  goes further than a pure lint-style "behavior-preserving" gate). It also
  includes **restructuring** — moving code, relocating routes, collapsing a guard
  to one place — when the reviewer named the target structure and the scope is
  clear, even though it's bigger than a one-liner. "Restructuring" is not
  automatically "architectural" (see Report only). And see "fix everywhere"
  below — a flagged spot usually isn't the only occurrence.
- **Ask first** — small, but it encodes a decision. The reviewer hedged
  ("vielleicht", "maybe", "or we could…"), offered an option rather than an
  instruction, or there's a value/name/default to pick. Two devs would plausibly
  diverge. Collect these and ask the user **before** editing, then fix the ones
  they decide on.
- **Report only** — the comment requires **choosing an approach**: introduce a
  new abstraction (a directive, a service, a pattern), pick between competing
  designs, or weigh a tradeoff the reviewer themselves is still unsure about. The
  test here is whether the _approach_ is a judgment call, not whether the change
  touches structure — a mechanical restructure with one obvious target is
  auto-fix (above), but "I'd build a directive for this" or "I'd rather do this
  via resolve" is a design decision. Also report when the comment points
  elsewhere without saying what ("siehe anderer MR", "see the other PR"), asks a
  question, or explicitly wants a third person's input. Don't guess intent —
  surface it with a pointer and move on.

When a comment could fall on either side of a line, step down a bucket
(auto-fix → ask, ask → report). A no-op is recoverable; a wrong edit to a
behavioral comment is not.

## Before you fix anything: is it already handled?

This is the failure mode that will bite first, so check it first. A thread shows
up as _unresolved_ even after the author has dealt with it — GitLab keeps it open
until someone clicks resolve. On a typical MR, **most unresolved threads are
already addressed.** Re-applying a fix that's already in the code (or double-
applying it) is the worst thing this skill can do.

For every thread, before classifying it as auto-fix, confirm it's still live:

1. **Did the author already reply?** A note from the MR author saying "done",
   "fixed", "changed in version X", "fixed in parent mr", etc. is a strong signal
   it's handled. (So is a `system: true` note like "changed this line in version
   N of the diff".)
2. **Does the current code still show the concern?** Open `position.new_path` and
   look at the referenced line/region. If the code already does what the reviewer
   asked, it's addressed.

If either says addressed → put it in the report as **"looks already handled"**
and touch nothing. Only fix threads where the current code still exhibits the
problem.

## "Fix everywhere" — generalize the safe fix, don't escalate it

When a reviewer flags one spot, they almost always mean the pattern, not just
that line ("here we have no default value…", "this would fire a query on every
navigation…"). So once a fix qualifies as auto-fix, **search the codebase for
every sibling occurrence and apply the same change to all of them** — grep for
the pattern, the symbol, the call shape. Fixing only the one line the reviewer
happened to point at leaves the same problem everywhere else.

But generalization is **gated by** the safe/precise test, not a way around it:

- Apply only the _same_ obvious transformation to each occurrence. If the other
  occurrences aren't clearly the same kind of thing, don't batch them in —
  surface the uncertain ones in the report.
- If "everywhere" means building a new abstraction or the surface is large
  (e.g. "there are more buttons like this… I'd build a directive for it" —
  build a directive and reroute many call sites), that is itself a **report**,
  not a mass edit. "Fix everywhere" can never promote an architectural comment
  into an auto-fix.

## Workflow

### 1. Find the MR and read its unresolved comments

The user is already authenticated via the `glab` CLI. Auto-detect the MR from
the current branch (pass the MR number or branch as a positional arg if the user
gave one):

```sh
glab mr view --unresolved --output json > <scratchpad>/mr.json
```

That returns the MR plus its unresolved discussions under the `Discussions` key
(capital D); the MR's own fields (`iid`, `state`, `author`, `reviewers`,
`web_url`) sit at the top level. Use `--jq` or read the file rather than
dumping the whole payload into context.

If there's no MR for the branch, or its `state` isn't `opened`, say so and stop.
If there are no unresolved comments, report that and stop — nothing to triage.

### 2. Extract the real reviewer comment from each thread

Each discussion's `notes` array mixes three things — isolate the signal:

- **Skip `system: true` notes** — these are GitLab's auto-generated "changed this
  line in version X" entries, not feedback.
- **Skip notes authored by the MR author** (the `author` field on the MR) — those
  are the user's own replies ("done", "fixed"). Use them only as the "already
  handled" signal from the previous section.
- **The reviewer's note** is the remaining one (typically the first note, from a
  user in `reviewers`). Its `body` is the comment; `position.new_path` and
  `position.new_line` (when present) anchor it to a file and line. A
  `DiscussionNote` with `position: null` is a general MR comment with no file
  anchor — read it, but you'll have to locate the relevant code yourself.

Reviewer comments are often **in German** — read and reason over them directly;
don't translate them into the report unless it helps clarity.

### 3. Triage every comment, then ask about the "ask" bucket

Go through each unresolved, still-live comment and assign a bucket using the
tests above. Before making any edits, if there are **ask-first** items, present
them to the user together and wait for their decisions — don't start fixing and
interrupt halfway. Something like: "Three comments need a call from you: …".
Once they answer, fold their decisions into the auto-fix set.

### 4. Apply the fixes

For each auto-fix item (and each ask item the user approved):

- Make the edit at the flagged location, then generalize to every sibling
  occurrence per "fix everywhere".
- Keep each fix scoped to what the comment asked. Don't opportunistically
  refactor nearby code — that widens the diff and muddies review.

### 5. Verify with the repo's own checks

The user chose verify-before-report. Run the repo's full pre-commit-level check,
inside its devShell. Find it, in roughly this order: the repo-specific skill or
`CLAUDE.md`; a `precommit`/`check`/`lint` script in `package.json`;
`.pre-commit-config.yaml` (`pre-commit run --all-files`); a `justfile` or
`Makefile` target; `cargo fmt --check && cargo clippy`; `nix flake check`. If
nothing obvious exists, run the linters/formatters the CI config runs, and say
which ones you picked.

A repo-wide check can fail for reasons that **predate your edits**. If it
goes red, separate the two: confirm whether the failure is in a file/rule you
touched or is pre-existing. Don't claim your fixes broke something they didn't —
and don't claim success while leaving a failure your edit caused. If a fix can't
pass the check cleanly, say so in the report and leave it (or revert it) rather
than forcing it through.

### 6. Report (in chat)

End with a clear summary covering **every** unresolved comment — the user reads
this to know what was done and what they still need to handle on GitLab
themselves. Use this shape:

```
## MR !<iid> review comments — <N unresolved>

### Fixed (in working tree, not committed)
- <file:line> — "<short quote of the comment>"
  Did: <what changed, and where else it was applied>. Checks: <result>.

### Decided with you, then fixed
- <file:line> — "<comment>" → you chose <decision>. Did: <what changed>.

### Looks already handled (not touched)
- <file:line> — "<comment>". Why: author replied "<…>" / code already does <…>.

### Needs your attention (not touched)
- <file:line> — "<comment>". Why reported: <architectural / vague / a question /
  wants another opinion>. Suggested next step: <pointer or what to clarify>.

### Reminders
- Nothing was committed, pushed, or posted to GitLab. Review the diff, then
  resolve/answer the threads yourself.
- Checks (<command>) verified locally; <note any pre-existing failures separated out>.
```

Be honest: if you weren't sure a comment was addressed, say so rather than
silently picking a bucket. Leave all changes unstaged.
