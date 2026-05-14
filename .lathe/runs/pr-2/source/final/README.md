# project

This is the user app worktree. Application code lives here.

The project root also contains:

- `lathe/` — Lathe control worktree on branch `lathe`
- `lathe-worktrees/` — per-run Lathe-managed task worktrees
- `.git/` — shared repo metadata

Typical flow:

```sh
cd ..
lathe feature feature-name
cd features/feature-name
# edit app code
git add . && git commit -m "..."
git push -u origin feature/feature-name
gh pr create --base main --title "..." --body "..."
```

Then from the project root:

```sh
lathe task process pr <pr#>
```

See `lathe help` for the full command list.
