---
name: real-e2e-validation
description: 実装後に mock なしで Lathe の実運用フローを検証する。lathe eval の fixture 比較ではなく、実際の gh / GitHub PR / Claude Code を使う E2E。
---

# real-e2e-validation

## 目的

実装が fixture や mock だけで通っている状態を採用しない。CLI、harness、workflow、delivery、transfer filter、helper documentation を変えたら、実際の `gh`、GitHub PR、`claude` を使って E2E を走らせる。

`lathe eval` は regression fixture runner。GitHub API を mock するため、最終的な E2E の代替ではない。

## 前提確認

```sh
gh auth status
claude --version
```

どちらかが使えない場合は採用しない。blocker として人間に戻す。

## 最小 E2E

隔離された一時ディレクトリと短命の private GitHub repo を使う。

```sh
root=$(mktemp -d /tmp/lathe-e2e-XXXXXX)
repo="lathe-e2e-$(date +%Y%m%d%H%M%S)"
mkdir -p "$root/project"
cd "$root/project"
lathe init

gh repo create "OWNER/$repo" --private --clone=false
git --git-dir=.git remote add origin "git@github.com:OWNER/$repo.git"
git -C main push -u origin main
git -C lathe push -u origin lathe
```

次に実 PR を作る。`.latheignore` filter を確認するため、feature 側に user-owned `.claude/` を含める。

```sh
lathe feature e2e-wc
cd features/e2e-wc
mkdir -p .claude
printf 'user owned\n' > .claude/user-owned.txt
# 小さい実変更を入れる。例: wc.py と test_wc.py
git add .
git commit -m "WIP: e2e prototype"
git push -u origin feature/e2e-wc
gh pr create --base main --head feature/e2e-wc --title "e2e wc tool" --body "TASK: ..."
```

## plan-only 検証

```sh
cd "$root/project"
lathe task plan --print pr <pr#>
```

確認すること:

- `lathe-worktrees/task-pr-<pr#>/.lathe/plans/*.html` が作られる
- task workspace の application files が plan-only で変更されない
- feature branch の `.claude/user-owned.txt` が task workspace に import されない
- task runtime の `.claude/` が PR head に export されない
- Claude 出力が contract / approval boundary で止まっている
- subagent dispatch、commit、push が起きていない
- `lathe/.lathe/runs/pr-<pr#>/` に task archive が作られ、remote がある場合は `origin/lathe` に push される

## process 検証

TUI をそのまま使えるなら使う。自動検証では `--print` を使う。

```sh
cd "$root/project"
lathe task process --print pr <pr#>
```

確認すること:

- 既存 plan が current diff と矛盾しなければ reuse される
- process invocation の plan approval grant が workflow に注入される
- 実装は `lathe-worktrees/task-pr-<pr#>/` の exportable application files にだけ入る
- tests/build が実行される
- task branch に local commit が作られる
- Lathe CLI が `.latheignore` filter 越しに PR head を更新する
- PR head に user-owned `.claude/` が残り、task runtime の `.claude/` は混ざらない
- `lathe/.lathe/runs/pr-<pr#>/summary.json`、`source/imported/`、`source/final/`、`patches/export.diff`、`exported-files/`、`sessions/` が存在する

## merge 検証

GitHub 側で PR を merge する。

```sh
gh pr merge <pr#> --merge
git -C main fetch origin main
git -C main merge --no-edit origin/main
```

確認すること:

- PR の成果物が base branch に入る
- `lathe` control branch に user application diff が混ざらない
- task 実行履歴は `lathe/.lathe/runs/pr-<pr#>/` archive として残る

## cleanup

ローカル一時ディレクトリは削除する。GitHub repo の削除には `delete_repo` scope が必要。削除できない場合は private repo 名を人間に報告する。

```sh
rm -rf "$root"
gh repo delete "OWNER/$repo" --yes
```

## summary への記録

```markdown
## Real E2E

- repo:
- PR:
- plan-only:
- process:
- transfer filter:
- tests:
- merge:
- cleanup:
- result: pass/fail
```

mock、fake `gh`、fake `claude`、`lathe eval` だけの結果を real E2E と呼ばない。
