---
name: harness-evals
description: .lathe/harness/ を変更した後、Lathe eval fixture を使って baseline と candidate の挙動差を確認する。fixture の選び方、実行コマンド、comparison.md の読み方を扱う。
---

# harness-evals

## 目的

harness 改善を「思いつきの prompt 追加」にしない。変更前後の harness を同じ fixture で走らせ、観察可能な差分を improvement の根拠にする。

`lathe eval` は GitHub API を mock する fixture 比較であり、実装後の mock なし E2E ではない。採用前の最終確認は `real-e2e-validation` skill に従う。

## 基本コマンド

control worktree から、変更前 harness と変更後 harness を比較する。変更前を `/tmp` 等へ退避して baseline に渡す。

```bash
cp -R .lathe/harness/task /tmp/lathe-baseline-task
lathe eval run pr-wc-basic \
  --baseline /tmp/lathe-baseline-task \
  --candidate .lathe/harness/task \
  --no-claude
```

`--no-claude` は PR/task worktree の再現だけを検証する dry run。Claude 実行まで見る場合は外す。

```bash
lathe eval run pr-wc-basic \
  --baseline /tmp/lathe-baseline-task \
  --candidate .lathe/harness/task \
  --model sonnet \
  --max-budget-usd 0.50 \
  --timeout 300
```

結果は project root の `harness-evals/results/<run_id>/comparison.md` に出る。baseline/candidate それぞれの `summary.json`、`lathe-command.log`、`claude.out`、隔離 project も残る。

## fixture の選び方

- `pr-wc-basic`: 通常の PR intake と plan-only 制約が壊れていないかを見る
- `pr-ambiguous`: 仕様不足タスクで、勝手に受入条件を作って進めないかを見る

変更した harness ファイルに応じて、関係する fixture を少なくとも1つ選ぶ。planning skill、workflow gate、task intake、invocation handling を触った場合は両方走らせる。

## 読む順序

1. `comparison.md` の command / claude exit / timeout を見る
2. `baseline/lathe-command.log` と `candidate/lathe-command.log` で `.lathe/task.json` / `.lathe/invocation.json` の生成に差がないか見る
3. Claude 実行ありなら `baseline/claude.out` と `candidate/claude.out` を読む
4. 隔離 project の `lathe-worktrees/task-pr-1/.lathe/plans/`、task workspace の git status、`.lathe/runs/` を読む
5. expected.md の観点に照らして、良化 / 悪化 / 判定不能に分ける

詳細な読み方は `eval-result-reading` skill に従う。`command=0` / `claude=0` は mechanical success であり、semantic success ではない。

## improvement summary への書き方

`.lathe/improvements/<id>/summary.md` には fixture 結果を短く添える。

```markdown
## Fixture

- fixture: pr-wc-basic
- result: ../harness-evals/results/20260513-123456-pr-wc-basic/comparison.md
- observation: candidate は plan-only で task workspace を編集しなかった。baseline/candidate とも command_exit=0。
- interpretation: 今回の変更は PR intake を壊していない可能性が高い。
- limitation: LLM 出力は非決定的なので、exact wording は評価しない。
```

## 判断基準

- 1 fixture の成功だけで一般化しない
- exact output を比較しない
- 悪化が出たら prompt を足す前に、workflow / protocol / event の不足を疑う
- candidate が baseline と同じ失敗をするなら、その fixture は regression 検出ではなく未解決課題として記録する

## fixture を増やすとき

人間が curated fixture として追加するのが基本。meta agent が勝手に大量生成しない。必要な fixture を提案する場合は、seed、feature.patch、task.md、expected.md の意図を improvement summary に書く。
