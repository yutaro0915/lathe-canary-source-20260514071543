---
name: experiment-design
description: harness 変更を仮説として設計し、変更前に評価方法・fixture・rollback 条件を決める。.lathe/harness/ を編集する直前に使う。
---

# experiment-design

## 目的

harness 改善を「注意書きの追加」ではなく、小さな実験として扱う。変更前に、何を良くしたいのか、どう測るのか、悪化したらどう戻すのかを決める。

## 実験メモ

`/tmp/lathe-experiment-<slug>.md` に下書きし、採用する場合は `.lathe/improvements/<id>/summary.md` に要約を写す。

```markdown
# Experiment: <slug>

## Observation

- Evidence:
- Affected run(s):
- Mechanical / semantic classification:

## Hypothesis

If we change <harness file / protocol / workflow>, then <observable behavior> will improve because <reason>.

## Change

- Files:
- Intended edit:
- Non-goals:

## Evaluation

- Fixture(s):
- Expected mechanical result:
- Expected semantic result:
- Manual checks:

## Regression Risk

- Possible downside:
- Prompt bloat risk:
- False-positive escalation risk:
- Overfitting risk:

## Rollback

- Revert condition:
- How to revert:
```

## fixture 選択

- task intake / invocation handling を触る: `pr-wc-basic`, `pr-ambiguous`
- planning skill を触る: `pr-wc-basic`, ambiguous 系 fixture
- workflow gate を触る: plan-only fixture と process fixture
- reviewer/coder dispatch を触る: 実装 fixture（未整備なら提案として記録）

fixture が足りない場合、harness 変更より先に「必要な fixture」を提案する。meta agent が勝手に大量生成しない。

## 変更の粒度

1 experiment = 1 hypothesis = 1 logical change。

避けるもの:

- 複数の独立改善を1 commit に混ぜる
- 既存 skill に長い禁止事項を追記するだけ
- 1 run の印象だけで一般 policy を足す
- fixture で見えない改善を「たぶん良い」として通す

## prompt bloat guard

新しい指示を足す前に、次を検討する。

- workflow YAML に構造化できないか
- plan template の項目で表現できないか
- event / log / protocol で明示できないか
- 既存の曖昧な文を短く置き換えられないか
- 不要になった指示を削れるか

追加文が必要なら、短く、検証可能な行動に落とす。

## 採用判断

eval 後、次のどれかに分類する。

- `adopt`: expected mechanical/semantic result を満たし、重大な regression なし
- `revise`: 方向は良いが fixture で failure あり。追加修正して再 eval
- `reject`: 仮説が外れた、または副作用が大きい
- `inconclusive`: 結果が非決定的。commit せず追加 fixture / run が必要

`adopt` 以外は、そのまま commit しない。
