---
name: split-branch
description: Split the current feature branch into a stack of small, easy-to-review sub-branches and open stacked draft GitLab MRs (assignee + reviewer = the current user) with git-spice. Also owns the life of the stack afterwards - working reviewer feedback into the right branch, restacking, propagating changes up the stack, and syncing after a part merges. Use whenever the user asks to split a branch, break up a big MR/diff, create stacked MRs, make a branch reviewable, or says something like "split this up for review", "push my fix up the stack", "restack", or "rebase the stack after part 1 merged". This skill redistributes existing changes only - it never writes or modifies code.
---

# Split branch into stacked GitLab MRs

Turn one large feature branch into a chain of small sub-branches, each with its own
draft MR, so reviewers see one coherent step at a time instead of one huge diff.
The split itself is done with plain git; the stack is then handed to **git-spice**,
which owns pushing, MR creation, retargeting, and restacking from then on.

## Hard rules

1. **Never change the code.** You are redistributing the existing diff, nothing else.
   No fixes, no refactors, no formatting, no "while I'm here". The tree at the tip of
   the last sub-branch must be **identical** to the tree of the original branch —
   this is verified with `git diff` before anything is pushed, and a non-empty diff
   means you made a mistake that must be fixed first.
2. **The original branch is never touched.** The split surgery happens on new branches
   in a temporary worktree; the user's checkout, working tree, and local env files stay as they
   are. The one thing this skill does leave behind is git-spice's tracking state in
   `.git/spice/` — that is deliberate, it is what makes the stack maintainable later.
3. **Nothing is pushed until the user approves the split plan.**
4. All MRs are created as **drafts**, with the current GitLab user as **assignee and
   reviewer**.

## Gotchas (read before running commands)

- **Repo-specific notes win.** This is a generic, personal skill. If the repo has
  `.claude/skills/split-branch/SKILL.md`, it is a repo-tailored version (hook
  side effects, migration/snapshot rules, typical part order). Personal skills
  shadow project skills of the same name, so it won't load on its own: read it and
  follow it where it is more specific. Also skim the repo's `CLAUDE.md`.
- **Always invoke `git-spice`, never `gs`.** git-spice's docs use `gs` as the command
  name, and on NixOS the package's own binary *is* `gs` — but that name collides with
  Ghostscript. The work-laptop config adds a `git-spice` name for it; use that so the
  command is unambiguous. Check auth once with `git-spice auth status` (if it's not
  logged in, ask the user to run `git-spice auth login` — it's interactive).
- **Git hooks with side effects.** Check what checkout-type hooks the repo runs:
  `git config core.hooksPath` (default `.git/hooks`) and look for `post-checkout`,
  `post-merge`, `post-rewrite`. Some repos migrate/seed a database, rewrite `.env`, or
  run installs on every branch switch — a restack across a 4-part stack would then run
  that four times. If such a hook exists, prefix plain git surgery with
  `-c core.hooksPath=/dev/null`, and prefix git-spice commands that check out branches
  (`restack`, `checkout`, `onto`, `repo sync`) with `$NOHOOKS`:

  ```bash
  # only when the repo has checkout hooks with side effects; otherwise leave it empty
  NOHOOKS="env GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null"
  $NOHOOKS git-spice upstack restack
  ```

  Disabling hooks also skips the LFS smudge (if an LFS-tracked file looks like a
  pointer afterwards, `git lfs checkout` restores it), and it skips whatever state the
  hook keeps in sync — see the resync note at the end of step 8.
- **Never bypass push hooks.** A `pre-push` hook is often `git lfs pre-push`, which
  uploads LFS objects, or a check the team relies on. Do not use `--no-verify` and do
  not apply `$NOHOOKS` to any push or `submit`; doing so can push commits whose LFS
  objects never reach the server.
- **Branch naming: `<TICKET>/<feature-name>`.** Do *not* extend the original branch
  name — that is what produces the unreadable
  `DEV-1234-some-long-ticket-title-copied-verbatim--1-backend-queries`. Restart from
  the ticket instead: `DEV-1234/backend-queries`, `DEV-1234/frontend-list`. Keep
  `<feature-name>` a short kebab-case phrase naming *that part's* concern, not the epic's.

  Get the ticket from the original branch name, which normally carries it:

  ```bash
  TICKET=$(git rev-parse --abbrev-ref HEAD | grep -oiE '(DEV|BR)-[0-9]+' | head -1 | tr a-z A-Z)
  ```

  It handles the `feature/DEV-5678-…` and `BR-42-…` shapes too. If the repo uses a
  different ticket prefix, adapt the pattern. **If that comes back empty, ask the user
  for the ticket number (or a prefix to use instead) — never invent one and never fall
  back to the long-name scheme.** Also confirm the ticket you extracted in the step 3
  plan, since a branch can carry a stale or wrong one.

  One collision to check: git cannot create `DEV-1234/foo` while a ref named exactly
  `DEV-1234` exists (a ref cannot also be a directory). Verify with
  `git rev-parse --verify --quiet "$TICKET"` — if that prints a sha, ask the user which
  prefix to use instead.
- **Files that must change together stay together.** A migration, the entity/schema
  change it implements, and any tracked schema snapshot belong in the **same** part —
  splitting them breaks CI migration checks. Likewise i18n/message-catalog entries go
  with the feature that introduced the strings (keys would be unused on their own), and
  lockfile changes go with the manifest change that caused them. Never include local,
  per-branch generated artifacts that happen to be committed by mistake — ask.

## Workflow

**Which half of this skill applies?** If `.git/spice` exists and `git-spice log short`
shows a tracked stack for this branch, the split has already happened — go straight to
**step 8**. Steps 1–7 are the first run only; never re-split an existing stack.

### 1. Take stock

```bash
git fetch origin
TRUNK=$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||')  # usually main
BASE=$(git merge-base origin/$TRUNK HEAD)   # confirm the branch is based on the trunk
git log --oneline $BASE..HEAD
git diff --stat $BASE..HEAD
```

Read the full diff (`git diff $BASE..HEAD`) well enough to understand what each
change does and what depends on what. Require no staged or unstaged changes; if
there are any, stop and ask the user to commit or stash first. Untracked files are
fine (many repos keep local generated artifacts lying around) —
they stay out of the split because you only move committed changes.

### 2. Design the split

Group the changes into 2–6 parts that each tell one story. Guidelines:

- **Dependency order**, so every part builds on the previous ones and the stack
  compiles at each step. A typical web-app order: database entities + migrations →
  shared/server logic → API surface → frontend → tests/i18n polish. But follow
  the actual dependencies, not the template.
- Aim for parts a reviewer can hold in their head (roughly ≤400 changed lines is a
  good target, not a law). One giant part defeats the purpose; ten trivial parts
  waste reviewer time.
- Prefer whole-commit and whole-file boundaries. Split within a file (hunk level)
  only when a file genuinely mixes concerns — it's the most error-prone operation.
- A commit's changes may be distributed across parts; the sub-branches get fresh
  commits with clear messages (match the repo's existing commit style — check `git log`). The
  original commits survive on the untouched original branch.

### 3. Present the plan and wait for approval

Show the user, per part: branch name (`$TICKET/<feature-name>`), MR title, the files
(or file:hunk subsets) it contains, and its target branch. Lead with the ticket number
you extracted so they can correct it before any branch is created — ask outright if the
original branch name yielded none. Use AskUserQuestion or a plain summary — but do
not create branches or push until they approve. Incorporate any regrouping they ask
for.

### 4. Build the stack (temp worktree, hooks off)

```bash
WT=<scratchpad>/split-branch-worktree
git -c core.hooksPath=/dev/null worktree add "$WT" $BASE
cd "$WT"
```

For each part N (in order):

```bash
git -c core.hooksPath=/dev/null switch -c "$TICKET/<feature-name>"   # forks from previous part's tip
# whole files: take them verbatim from the original branch
git restore --source=<original-branch> -- path/a path/b …
# mixed files, preferred: when the original commits already separate the concerns,
# apply that file's changes commit by commit — part N gets the commits that belong
# to it. Applied in original commit order across parts, these compose exactly:
git show <commit> -- path/mixed.ts | git apply
# mixed files, fallback (concerns mixed within one commit): extract a patch and
# edit it down to the wanted hunks (keep the file header; delete whole @@ hunks,
# never lines inside one), then git apply it
git add -A && git commit -m "<message>"
```

Prefer the per-commit route — it never invents patch content, so mistakes show up
as a failed `git apply`, not as silently wrong code. After building each part,
`git diff HEAD <original-branch> -- path/mixed.ts` should show exactly the changes
deferred to later parts.

### 5. Verify the invariant (mandatory gate)

```bash
git diff <last-part-branch> <original-branch>
```

This must print **nothing**. If it doesn't, the split lost or altered changes — fix
the stack before going anywhere near `push`. Also sanity-check each boundary with
`git diff --stat` between consecutive parts to confirm it matches the approved plan.

### 6. Remove the worktree, then hand the stack to git-spice

The worktree must go **before** tracking: a branch checked out in a worktree cannot
be checked out in the main repo, and every later restack needs exactly that.

```bash
cd <repo root>
git -c core.hooksPath=/dev/null worktree remove --force "$WT"

# one-time per repo — skip entirely if .git/spice already exists.
# NEVER pass --reset: it untracks every stack in the repo, including unrelated ones.
[ -d .git/spice ] || git-spice repo init --trunk "$TRUNK" --remote origin --no-prompt

# delete each source branch on merge (repo-local; safe to re-run)
git config spice.forge.gitlab.removeSourceBranch true

# track the whole stack in one go, from the TOP branch downwards
git-spice downstack track <last-part-branch>
git-spice log short
```

`downstack track` *guesses* each branch's base. Read `git-spice log short` and confirm
it shows the expected linear stack with the expected bases before submitting anything —
a wrong guess creates an MR against the wrong target. Fix with
`git-spice branch track <branch> --base <correct base>`.

### 7. Submit the stack

Write each MR description to its own temp file first (multiline flags are fragile),
then submit **bottom-up**, one branch at a time — `stack submit` cannot carry a
distinct body per MR.

```bash
USERNAME=$(glab api user --jq .username)

git-spice branch submit --branch "$TICKET/<part-1-name>" --dry-run   # pre-flight
git-spice branch submit --branch "$TICKET/<part-1-name>" \
  --draft --title "<concise title>" --body "$(cat /tmp/mr-1.md)" \
  --reviewer "$USERNAME" --assign "$USERNAME"
# … repeat for parts 2..N, in ascending order
```

git-spice derives each MR's target branch from the tracked stack, so part 1 targets
`main` and part N targets part N-1 automatically, and `--nav-comment` (on by default)
posts a stack-navigation comment on every MR and keeps it current. Do **not** hand-write
stack position into the descriptions.

`submit` has no `--remove-source-branch` flag; the `spice.forge.gitlab.removeSourceBranch`
config set in step 6 replaces it, so a merged part's branch is deleted and GitLab
retargets whatever sat on top of it. `git-spice repo sync` (step 8) then brings the local
stack in line.

### 8. Iterating on reviewer feedback (the stack's ongoing life)

This is where a stack normally hurts, and where git-spice earns its place. The
discipline that matters: **fix the problem in the branch that owns it**, not on top of
the stack. A comment on part 2's code gets fixed on part 2's branch; everything above
is then replayed.

```bash
$NOHOOKS git-spice branch checkout DEV-1234/backend-queries
# … make the fix, then:
git add -A && git commit -m "<message>"
$NOHOOKS git-spice upstack restack      # replays parts 3..N onto the new part 2
git-spice stack submit --update-only    # force-pushes and updates the existing MRs
```

`--update-only` deliberately creates nothing new, so a stray untracked branch cannot
turn into a surprise MR. If a restack hits a conflict, resolve it and
`git-spice rebase continue`.

**Resync hook state when you are done (only if you used `$NOHOOKS`).** Unlike steps
1–7, this step moves the user's *real* checkout, and `$NOHOOKS` suppresses whatever the
checkout hook keeps in sync with the current branch (e.g. a per-branch database URL in
`.env`). Left alone, the user ends up on one branch while that state still points at
another, and the next `serve` or `seed` silently talks to the wrong database. Skipping
the hook per checkout is the point — running it **once** at the end is the price:

```bash
"$(git rev-parse --git-path hooks)/post-checkout" HEAD HEAD 1   # or the core.hooksPath dir
```

After a part is merged into `main`:

```bash
$NOHOOKS git-spice repo sync --restack
```

That pulls `main`, deletes the merged branch, retargets what sat on top of it onto
`main`, and restacks the remainder. Follow with `git-spice stack submit --update-only`
to push the rebased branches.

Reordering or dropping a part: `git-spice downstack edit` (reorder),
`git-spice upstack onto <new base>` (move a subtree), `git-spice branch fold` (merge a
part into the one below it).

### 9. Report

Confirm the user's original checkout is untouched (`git status`), then report the
stack: each MR's title, URL, and target, in merge order. `git-spice log long` shows
the tracked stack with its commits.

## MR description template

Keep it short — usually under ~15 lines. The reviewer reads this to know *where they
are* before opening the diff; the diff itself carries the technical detail.

```markdown
## Overview
<2–3 sentences in plain language: what this part achieves and why it exists, framed
so someone who has not read the epic can follow it. No file names, no symbol names.>

## What changed
<a handful of bullets grouped by concern, not by file — "adds the X entity and its
migration", not a per-file walkthrough. If a bullet needs a file path to make sense,
that is fine; a list that is only file paths is not.>

## How to test
<steps to verify this part, if it is testable on its own; otherwise state what
blocks testing, e.g. "UI lands in part 3 — testable end-to-end there">

## Review notes
<only what would otherwise trip the reviewer up: temporary states a later part
resolves, deliberate omissions, things already reviewed in a sibling MR. Omit the
section if there is nothing to say. Do NOT restate the stack position — the
git-spice navigation comment already does that and stays current.>
```
