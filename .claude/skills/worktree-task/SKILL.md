---
name: worktree-task
description: Start, verify, and finish a unit of work in this repo using the multi-agent worktree workflow — claiming a task, creating a feature worktree/branch, running the check gate before committing, and cleaning up after merge. Use when starting parallel or feature work, when asked to create a worktree or branch for a task, or when wrapping up a task with commits.
---

# Worktree task workflow

Worktrees are siblings under `../` (the shared `worktrees/` directory), one
per task, one agent per worktree. Never edit a worktree you did not create.

## Start a task

From the main checkout (`worktrees/lyingshell`), first check the task is not
already claimed — an existing `<type>/<slug>` branch or worktree **is** the
claim:

```bash
git fetch origin
git worktree list
git branch -a
```

If a branch or worktree for the task already exists, another agent owns it:
pick a different task or coordinate; do not create a duplicate. Otherwise
claim it:

```bash
git worktree add ../lyingshell-<slug> -b <type>/<slug> origin/main
```

- `<slug>`: short kebab-case task name (e.g. `notification-panel`).
- `<type>`: `feat`, `fix`, or `refactor`.
- Branch from `origin/main`, not local HEAD, unless the task explicitly
  builds on another branch.

Work only inside that new worktree from then on.

## Check gate (before every commit)

```bash
scripts/check.sh
```

One script, same as CI: Qt6 qmllint over all tracked production QML, then
every `tests/test_*.py`. Tests that print `SKIP` are fine; anything else
non-zero blocks the commit. `CHECK_SKIP_LINT=1` skips lint if the QML tooling
is unavailable in your environment.

## Commit

- Small commits, one logical change each.
- Subject line: imperative, lower-case type prefix matching the branch
  (`feat: add notification panel surface`).
- New visible strings must land in both `Commons/I18n/locales/en.json` and
  `zh-CN.json` in the same commit, with keys kept alphabetically sorted at
  every nesting level (`tests/test_i18n_locales_contract.py` enforces this).
- If you intentionally change a QML contract, update the matching
  `tests/test_*_contract.py` in the same commit.

## Finish a task

1. Rebase on `origin/main`, re-run the check gate.
2. Push the branch and open a PR to `main` (or merge locally if told to).
3. After merge, from the main checkout:

```bash
git worktree remove ../lyingshell-<slug>
git branch -d <type>/<slug>
```

Never delete a worktree directory with plain `rm -rf` — always
`git worktree remove`, which also releases the claim. If a directory was
removed by hand, run `git worktree prune` from the main checkout to clear the
stale registration.
