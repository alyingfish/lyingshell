---
name: worktree-task
description: Start, verify, and finish a unit of work in this repo using the multi-agent worktree workflow — creating a feature worktree/branch, running the check gate before committing, and cleaning up after merge. Use when starting parallel or feature work, when asked to create a worktree or branch for a task, or when wrapping up a task with commits.
---

# Worktree task workflow

Worktrees are siblings under `../` (the shared `worktrees/` directory), one
per task, one agent per worktree. Never edit a worktree you did not create.

## Start a task

From the main checkout (`worktrees/lyingshell`):

```bash
git fetch origin
git worktree add ../lyingshell-<slug> -b <type>/<slug> origin/main
```

- `<slug>`: short kebab-case task name (e.g. `notification-panel`).
- `<type>`: `feat`, `fix`, or `refactor`.
- Branch from `origin/main`, not local HEAD, unless the task explicitly
  builds on another branch.

Work only inside that new worktree from then on.

## Check gate (before every commit)

```bash
qmllint -I "$HOME/.local/lib" shell.qml
for t in tests/test_*.py; do python3 "$t" || exit 1; done
```

Also lint any QML file you changed. Tests that print `SKIP` are fine;
anything else non-zero blocks the commit.

## Commit

- Small commits, one logical change each.
- Subject line: imperative, lower-case type prefix matching the branch
  (`feat: add notification panel surface`).
- New visible strings must land in both `Commons/I18n/locales/en.json` and
  `zh_CN` in the same commit.

## Finish a task

1. Rebase on `origin/main`, re-run the check gate.
2. Push the branch and open a PR to `main` (or merge locally if told to).
3. After merge, from the main checkout:

```bash
git worktree remove ../lyingshell-<slug>
git branch -d <type>/<slug>
```
