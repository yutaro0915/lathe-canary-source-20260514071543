---
name: eval-result-reading
description: lathe eval run の result directory を読み、comparison.md / summary.json / claude.out / plan HTML / expected.md を照合して mechanical success と semantic success を判定する。
---

# eval-result-reading

## 目的

`lathe eval run` の結果を、単なる exit code ではなく harness 改善の採用判断に使える形へ変換する。

## 読むファイル

result directory:

```text
harness-evals/results/<run_id>/
  run.json
  comparison.md
  baseline/
    summary.json
    lathe-command.log
    claude.out
    claude.err
    project/
  candidate/
    summary.json
    lathe-command.log
    claude.out
    claude.err
    project/
```

fixture directory:

```text
template/evals/fixtures/<fixture>/
  manifest.json
  expected.md
  task.md
  feature.patch
```

## 読む順序

1. `run.json` で fixture、baseline、candidate、mode、timeout を確認
2. `comparison.md` で command / claude / timeout / plans / dirty 状態を確認
3. `candidate/summary.json` と baseline があれば `baseline/summary.json` を読む
4. `candidate/lathe-command.log` で task envelope が作れたか確認
5. `candidate/claude.out` と `candidate/claude.err` を読む
6. `candidate/project/lathe-worktrees/task-pr-<n>/.lathe/plans/*.html` を読む
7. `candidate/project/lathe-worktrees/task-pr-<n>` の git status / diff を必要に応じて見る
8. fixture の `expected.md` と照合する

## mechanical 判定

```markdown
## Mechanical

- command_exit:
- claude_exit:
- claude_timed_out:
- plan_count:
- task_dirty:
- control_dirty:
- result: pass/fail
```

目安:

- `command_exit != 0`: fail
- Claude 実行ありで `claude_exit != 0`: fail
- `claude_timed_out=true`: fail
- plan mode で `plan_count < 1`: fail
- plan-only で `task_dirty=yes`: fail
- `control_dirty=yes`: 通常は要確認。eval runner が期待していない control worktree 変更が残っている可能性がある

## semantic 判定

```markdown
## Semantic

- expected.md item:
  - observed:
  - verdict: pass/fail/inconclusive
- overall: pass/fail/mixed/inconclusive
```

semantic 判定は exit code では決めない。`expected.md` に対して、Claude の plan / final output / dirty status / logs が合っているかを見る。

例:

- `pr-wc-basic`: plan-only で plan を作り、task workspace を触らず、実装は後続 process に回したら pass
- `pr-ambiguous`: 仕様不足として質問または escalation するなら pass。vibe code を product requirement と同一視して進めたら fail または mixed

## baseline / candidate 比較

baseline がある場合:

- candidate が baseline の mechanical failure を直したか
- candidate が新しい mechanical failure を作っていないか
- semantic failure が改善したか
- output が短くなった / 明確になった / escalation が適切になったか
- prompt bloat や過剰 escalation が増えていないか

LLM の文面の exact match は見ない。

## improvement summary への転記

```markdown
## Eval

- fixture: <name>
- result: ../harness-evals/results/<run_id>/comparison.md
- baseline: pass/fail/not-run
- candidate mechanical: pass/fail
- candidate semantic: pass/fail/mixed/inconclusive

### Observation

...

### Interpretation

...

### Decision

adopt / revise / reject / inconclusive
```

`candidate semantic != pass` の場合は原則 commit しない。例外的に commit するなら、人間に理由を明示する。
