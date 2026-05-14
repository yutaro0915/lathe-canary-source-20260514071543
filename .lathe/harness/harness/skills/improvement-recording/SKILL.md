---
name: improvement-recording
description: .lathe/harness/ に加えた改善を .lathe/improvements/<id>/ に記録する。summary.md(何を、なぜ、何を根拠に)と changes.patch(git diff)の書き方を扱う。harness に変更を加える際に参照する。
---

# improvement-recording

## 何を記録するか

harness に変更を加えたら、そのたびに `.lathe/improvements/<id>/` を作る。記録の目的は、後から人間(自分自身を含む)が「いつ・何を・なぜ変えたか」を辿れるようにすること。

軽微な変更でも記録する。記録するコストが高ければ「軽微なら飛ばす」判断が紛れ込み、振り返りが効かなくなる。

## id の付け方

`YYYYMMDD-HHMMSS-<slug>`

slug は変更の主題を 3-5 単語、ケバブケース、英数字とハイフンのみ。例：

- `20260511-093015-tighten-planning-skill`
- `20260511-110422-add-deviation-check-hook`

## 配置

```
.lathe/improvements/<id>/
├── summary.md
└── changes.patch
```

必要なら補足ファイルを足してよい(観察メモ、参照ログの抜粋など)。固定スキーマではない。

## summary.md に書くこと

最低限、次が読み取れるように書く：

- **何を変えたか** — 触ったファイル、変更の要旨
- **なぜ変えたか** — どのログから何を観察し、どう解釈したか
- **何を期待しているか** — 適用後に何が改善されるか(観察可能な形で)
- **どう評価したか** — fixture を走らせた場合は result path、mechanical 判定、semantic 判定、採用判断
- **mock なし E2E** — 実際の gh / GitHub PR / claude で何を通したか。実行できなかった場合は blocker として書く
- **副作用の可能性** — 思いつくリスク、想定していない動作

形式は決めない。短い変更なら数行で済むし、込み入った変更なら長くなる。テンプレートに従うことより、後から読んで理解できることを優先する。

参考に、軽い変更の例：

```markdown
# planning skill のチェックリスト削除

## 何を
.claude/skills/planning/SKILL.md の末尾「良い計画書のチェック」と「ありがちなミス」を削除。

## なぜ
.lathe/runs/20260511-* を 5 件読んだところ、orchestrator が計画書を起草する段階で、本文と末尾チェックリストを両方参照して context が長くなっていた。チェックリストの内容は本文に重複して書かれており、削っても情報は失われない。

## 期待
計画書起草時の context 消費が減る。orchestrator がチェックリスト消化を目的化する傾向も減るはず。

## 評価
fixture: pr-wc-basic
result: ../harness-evals/results/20260511-120000-pr-wc-basic/comparison.md
mechanical: pass
semantic: pass
decision: adopt

## Real E2E
repo: yutaro0915/lathe-e2e-YYYYMMDDHHMMSS
plan-only: pass
process: pass
tests: pass
merge/sync: pass
cleanup: local temp removed, remote repo deletion unavailable without delete_repo scope

## リスク
チェックがないと抜けが出る可能性はある。次の数 run で計画書の質が落ちないか確認する。
```

込み入った変更ならもっと書くし、根拠ログの行番号や session_id を引用する。

## changes.patch

`git diff` でそのまま生成できる形式。`git apply` で再現可能であること。

```bash
git diff -- .lathe/harness > .lathe/improvements/<id>/changes.patch
```

複数ファイルにまたがる変更も1つの patch にまとめる。論点が複数あるなら improvement を分ける(1 改善 = 1 論点)。論点が分かれていない束ね patch は、後で「この部分だけ revert」ができなくなる。

## 1 改善 1 論点

1つの improvement が複数の独立した変更を含むと、後から効果検証ができない。「この変更でうまくいったが、別の変更で悪化した」が混ざる。

迷ったら分ける。

## 記録のタイミング

harness に書き込む前に summary.md の下書きを始めてもよいし、書き込んだ後にまとめてもよい。決まった順序はないが、変更が確定したら忘れる前に記録を完成させる。後回しにすると、何を考えていたかが薄れる。

## 既存改善の参照

過去の improvement を読み返すのは推奨。同じ箇所を繰り返し触っているなら、根本原因を見落としているサインかもしれない。

```bash
ls .lathe/improvements/
# 同一ファイルを触った過去 improvement を探す
grep -l "planning/SKILL.md" .lathe/improvements/*/summary.md
```
