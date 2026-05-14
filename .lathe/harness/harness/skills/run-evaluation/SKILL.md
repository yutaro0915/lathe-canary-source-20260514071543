---
name: run-evaluation
description: .lathe/runs/<session_id>/ を評価し、task/harness runtime の成功・失敗・改善候補を mechanical / semantic に分けて整理する。log-reading の後、harness を変更する前に使う。
---

# run-evaluation

## 目的

session ログを「何となく読む」のではなく、改善判断に使える評価メモへ変換する。観察、解釈、改善候補を分け、1 run の偶発事象を即 harness 変更にしない。

## 入力

- `.lathe/runs/pr-<n>/summary.json`
- `.lathe/runs/pr-<n>/task.json`
- `.lathe/runs/pr-<n>/brief.md`
- `.lathe/runs/pr-<n>/invocation.latest.json`
- `.lathe/runs/pr-<n>/source/imported/`
- `.lathe/runs/pr-<n>/source/final/`
- `.lathe/runs/pr-<n>/sessions/<sid>/events.jsonl`
- `.lathe/runs/pr-<n>/sessions/<sid>/transcript.jsonl`
- `.lathe/runs/pr-<n>/sessions/<sid>/subagents/*.jsonl`
- 対応する `.lathe/runs/pr-<n>/plans/<run_id>.html`
- `.lathe/runs/pr-<n>/patches/export.diff`
- `.lathe/runs/pr-<n>/exported-files/`

まず `log-reading` skill でファイル構造と読み方を確認する。

## 評価表

run ごとに次を埋める。

| 観点 | mechanical | semantic |
|---|---|---|
| intake | task/brief/invocation を読んだか | task.json を policy と誤解していないか |
| workflow | workflow を明記したか | workflow 選択が task に合っているか |
| gate | plan-only/process の intent を守ったか | human escalation / approval 判断が妥当か |
| plan | plan HTML を作ったか | plan が source facts と current diff に合っているか |
| dispatch | coder/reviewer をいつ起動したか | dispatch の粒度・context が適切か |
| edits | task workspace だけを触ったか | 変更が計画・受入条件と一致しているか |
| validation | test/build/review を実行したか | 検証がリスクに見合っているか |
| delivery | commit/push したか | delivery adapter と source.head_branch を守ったか |
| recovery | error 後に止まったか | retry / escalation の判断が妥当か |

mechanical はログから直接確認できる事実。semantic は expected behavior や task intent との照合。

## 出力フォーマット

作業メモは `/tmp/lathe-run-evaluation-<sid>.md` などに書いてよい。improvement summary には必要部分だけ写す。

```markdown
# Run evaluation: <sid>

## Mechanical

- intake: pass/fail, evidence: events line / transcript note
- workflow: pass/fail, evidence:
- gate: pass/fail, evidence:
- plan: pass/fail, evidence:
- dispatch: pass/fail, evidence:
- edits: pass/fail, evidence:
- validation: pass/fail, evidence:
- delivery: pass/fail, evidence:

## Semantic

- outcome: success / failure / mixed / inconclusive
- observation:
- interpretation:
- impact:

## Improvement candidates

1. candidate:
   - evidence:
   - hypothesis:
   - likely file:
   - fixture to run:
   - risk:

## Do not change yet

- Things observed once but not enough to justify harness change.
```

## 判定ルール

- `command_exit=0` や reviewer approve だけで semantic success としない
- plan-only で task workspace が汚れたら mechanical failure
- process で plan approval grant があるのに、理由なく approval 待ちだけで止まったら semantic failure
- ambiguous task で vibe code を product requirement と同一視した場合は要注意。prototype evidence と requirement source を分けて評価する
- high-risk / unclear / validation impossible で escalation した場合、それは failure ではなく成功の可能性がある

## 改善候補にしてよい条件

- 同じ failure が複数 run で出ている
- 1 run でも protocol 違反が明確
- fixture で再現できる、または新 fixture として切り出せる
- 変更対象が具体的に分かる

条件を満たさない場合は harness を変えず、observation として残す。
