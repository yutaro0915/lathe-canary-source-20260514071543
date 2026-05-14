---
name: planning
description: タスク受領時に計画書HTMLを起草・保存する手順。plan_template.html を雛形として用い、`.lathe/plans/<run_id>.html` に出力する。計画書は採用 workflow の実行契約として機能するため、合意可能な粒度・検証可能な受入条件・図を含むこと。
---

# planning

## いつ使うか
新しいタスクを受領した直後、coder/reviewer に dispatch する前。計画から逸脱して workflow gate の再判定が要る場合の改訂時にも使う。

## 出力先と run_id
- 雛形：`plan_template.html`
- 出力：`.lathe/plans/<run_id>.html`
- run_id 命名（**例外なし**）：`YYYYMMDD-HHMMSS-<short_slug>`
  - timestamp 部は `date -u +%Y%m%d-%H%M%S` で必ず取得した実時刻。手書き禁止
  - slug はタスクの主題を 3-5 単語、ケバブケース、英数字とハイフンのみ
  - 例（OK）：`20260510-143022-add-login` / `20260511-094501-fix-cors-bug`
  - 例（**禁止**）：`add-login.html` / `task-001.html` / `wc-cli.html` / `<slug>-<n>.html` 等、timestamp が無いもの
- 改訂時：同じ run_id のファイルを上書きし、契約セクションの「修正履歴」に追記
- 計画書を書き始める前に必ず `date -u +%Y%m%d-%H%M%S` を Bash で取得し、その値を timestamp 部に使う。これは workflow の出発点で行う最初の操作です

## 雛形の使い方
雛形は `{{...}}` プレースホルダを含む。これを全て埋める。空欄を残さない。書くことがない欄は「該当なし」と明記する（沈黙しない）。

## セクションごとの埋め方

### 1. タスク解釈
雛形では 1.1 / 1.2 / 1.3 に分かれている。
- **1.1 受領した依頼（原文）**：原文をそのまま引用。改変しない
- **1.2 orchestrator の理解**：自分の言葉で言い直す。原文をなぞるのではなく、目的・スコープ・前提を解きほぐす。言い直しが原文より短くなったら情報を落としすぎている
- **1.3 目的・スコープ・前提**：表を埋める。「スコープ内」「スコープ外」を両方書く（境界の合意が後の逸脱判定の基準になる）。前提条件は「これが崩れたら計画が崩れる」事項を列挙
- `.lathe/task.json` がある場合は、source type/id、base branch、head branch、task branch、task worktree を 1.2 または 1.3 に必ず含める。後続の `lathe process` が既存計画を同定するための手掛かりになる
- `.lathe/invocation.json` がある場合は、invocation intent と injected dependencies / constraints を 1.2 または 1.3 に必ず含める。ただしこれは workflow 選択ではなく、採用 workflow が消費する依存性として記述する
- `execute_task` で `.lathe/invocation.json` の `injected_dependencies.existing_plan_candidates.paths` が空でない場合、新規 run_id を作らず最新の整合する既存 plan を更新する。候補が整合しない場合は新規 plan を作って進めるのではなく human escalation する

### 2. 採用ワークフロー
- `workflow/` から1つ選ぶ（YAML ファイル）
- 「なぜこのテンプレートか」を必ず書く。デフォルト（`workflow/default.yaml`）を選ぶときも理由を書く
- `lathe process` 起動で `.lathe/invocation.json` が `plan_approval` grant を注入している場合は、採用 workflow がその grant をどう消費するか、または消費できず human escalation する理由をここか契約セクションに明記する

### 3. 実装計画
- **3.1 概要**：文章で全体像
- **3.2 構造図**：Mermaid（`flowchart` `classDiagram` `sequenceDiagram` から適切なもの）。図なしは認めない
- **3.3 主要な変更**：追加・変更・削除されるファイルを明示

### 4. 役割分担
雛形は3列：Agent / 担当 / 非担当（誤解防止）。
- 「担当」と「非担当」の両方を埋める。非担当を明記することで scope creep を防ぐ
- 「coder：実装全般、reviewer：レビュー全般」のような曖昧記述を禁止する
- 「全部やらせる」は禁止。分担を明確にする

### 5. 成果物
- 完了時に存在しているべき具体物（ファイル・機能・ドキュメント）

### 6. 受入条件
- **検証可能な形で書く**。「動くこと」ではなく「`pnpm test` が緑になる」「`/login` で email/password を送ると 200 が返り `/dashboard` へリダイレクト」のように
- 検証手段が思い浮かばない条件は曖昧。書き直す

### 7. リスク・未解決の質問
- 計画段階で曖昧な点があれば全部ここに出す
- 1つでもあるなら status は `draft` のまま。human approval や auto gate には進まない

### 8. 実行フロー
- Mermaid `sequenceDiagram` で actors（Human, Orchestrator, Coder, Reviewer）と呼び出し順を描く
- 採用ワークフローと整合していること

### 契約セクション
- 提出日時・承認日時・承認者・完了日時・status を記録
- 修正履歴は append-only。古い記述を消さない。逸脱が起きた場合は「何を、なぜ変えたか」を記録する
- 「承認に伴う合意事項」セクションは雛形のまま残す。タスク固有の合意があれば追記する
- `.lathe/invocation.json` の `plan_approval` grant を採用 workflow が消費して進む場合、承認日時は gate 通過時刻、承認者は `lathe process invocation` とし、「lathe process の injected dependency により計画承認gateを満たした」と修正履歴または合意事項に記録する

## 図は Mermaid で書く
将来 PR で人間に渡されることを想定し、GitHub が描画できる Mermaid を使う。画像埋め込みや独自記法は使わない。

## status 遷移

```
draft → awaiting_approval → approved → in_progress → completed
                                          ↑           ↓
                                       amended ←── （逸脱発生時）
```

- 起草中は `draft`
- 人間に出した時点で `awaiting_approval`
- 人間の承認、または採用 workflow の auto gate を通過したら `approved`、dispatch 開始で `in_progress`
- 完了で `completed`
- 実行中に計画変更が必要になったら `amended` に戻し、修正→採用 workflow の gate 再判定
