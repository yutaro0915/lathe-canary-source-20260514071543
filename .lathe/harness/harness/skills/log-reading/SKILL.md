---
name: log-reading
description: task/harness runtime が .lathe/runs/<session_id>/ に残すログを読む。events.jsonl(hook が吐いた構造化イベント)と transcript.jsonl(Claude Code 純正 transcript)の形式、両者の突合、計画書との照合を扱う。.lathe/runs/ 配下のログを分析するときに参照する。
---

# log-reading

## ログの場所

task agent の実行が成功すると、Lathe CLI が task workspace 側の観測ログを control workspace の `.lathe/runs/pr-<n>/` に archive する。meta agent は通常この archive を読む：

```text
.lathe/runs/pr-<n>/
  summary.json
  task.json
  brief.md
  invocation.latest.json
  invocation-plan.json
  invocation-process.json
  source/
    imported/          # task が開始時に見た full filtered source tree
    final/             # task 完了時の full filtered source tree
    imported.files.txt
    final.files.txt
  plans/
  sessions/
    <session_id>/
      events.jsonl
      transcript.jsonl
      subagents/
  exported-files/
  exported-files.txt
  patches/
    task-branch.diff
    export.diff
    export.name-status.txt
  git/
    task-log.txt
    task-head.txt
```

`lathe-task/*` branch は内部作業 branch であり、外部から見る正本は `lathe` branch の archive。task が見たソース全体は `source/imported/` と `source/final/`、実装差分は `patches/export.diff`、export 後のファイル実体は `exported-files/`、追加・変更・削除の一覧は `patches/export.name-status.txt` を読む。

task agent または harness agent が動くと、実行中の workspace では `.lathe/runs/<session_id>/` にログが残る：

- `events.jsonl` — hook が吐いた構造化イベント。1 行 1 イベント
- `transcript.jsonl` — orchestrator（親 Claude）の transcript スナップショット。`Stop` または `PreCompact` 発火時に取得
- `subagents/agent-<agent_id>.jsonl` — orchestrator が `Task` で起動した subagent（coder/reviewer 等）ごとの transcript スナップショット。`SubagentStop` 発火時に取得。1 ファイル = 1 subagent インスタンス

session_id は **parent と subagent で共有**される。subagent ごとの識別子は `agent_id`（events.jsonl の SubagentStart/SubagentStop payload にある）。

スナップショットの取得方式（`copy_transcript.sh`）：
- 即時 cp（partial になっても必ず最初に1つコピーが残る）
- `Stop` / `SubagentStop`：source ファイルのサイズが 0.5 秒間隔で 2 回連続変化しなくなる（= writer が flush し終わった）まで最大 3 秒待ち、再コピー。`stop_reason` ではなくサイズ安定性で判定するのは、1 ターンが thinking 用 / text 用の複数 assistant レコードに分かれる場合があり、`stop_reason=end_turn` だけでは中間段階で誤確定するため
- `PreCompact`：圧縮直前の coherent な状態なので待たず即時 cp して終わり
- `last-prompt` 等の session メタデータはコピー後に live 側に追記される場合があり、コピーに無くても異常ではない（会話本体には影響しない）

subagent の動きを観察するときは `subagents/` 配下の transcript を読む。orchestrator 側の transcript からは Task tool 呼び出し（`tool_name: "Agent"`、`subagent_type` 入り）と subagent report しか見えない。実際の coder の Bash 呼び出しや reviewer の Read 内容などは subagent 側の transcript にある。

`SubagentStop` event の payload には `agent_id` / `agent_type`（"coder", "reviewer" 等）/ `agent_transcript_path` / `last_assistant_message`（subagent の最終発話）が入っており、深掘り前の概観として読みやすい。

## events.jsonl の形式

各行はこの形：

```json
{
  "ts": "ISO8601 UTC ミリ秒",
  "event": "SessionStart | UserPromptSubmit | PreToolUse | PostToolUse | SubagentStart | SubagentStop | PreCompact | Stop",
  "session_id": "...",
  "payload": { <hook が stdin で受け取った生 JSON> }
}
```

`payload` の中身は event 種別ごとに異なる。よく使うフィールド：

- 全イベント：`session_id`, `transcript_path`, `cwd`, `hook_event_name`
- PreToolUse / PostToolUse：`tool_name`, `tool_input`, (Post のみ)`tool_response`
- UserPromptSubmit：`prompt`
- SessionStart：`source`(`startup` / `resume` / `clear` / `compact`)
- SubagentStart / Stop：subagent 情報
- PreCompact：`trigger`(`auto` / `manual`)
- Stop：`stop_hook_active`

## transcript.jsonl の形式

Claude Code 純正フォーマット。1 行 1 レコードの JSONL。レコードは「会話ノード」と「session メタデータ」の混在。type で見分ける。

### 会話ノード（uuid / parentUuid / timestamp あり、親子で辿れる）

- `user` — 2形態あり、`toolUseResult` の有無で見分ける
  - 生ユーザー入力：`message.content` が string、`toolUseResult` なし
  - tool result：`message.content` が `[{type:"tool_result", ...}]`、`toolUseResult` と `sourceToolAssistantUUID` あり
- `assistant` — モデル出力。`message.content` は配列で次のブロック型が混在：
  - `text` — 通常のテキスト
  - `thinking` — 拡張思考
  - `tool_use` — tool 呼び出し
- `system` — システム生成のレコード。`subtype` で内訳が分かれる
  - `stop_hook_summary` — Stop hook の集計（`hookCount` / `hookInfos` / `hookErrors` / `stopReason` など）
  - その他の subtype も存在し得る（このリストは網羅ではない）
- `attachment` — 会話ノードに紐付く sidecar 情報。`attachment.type` で内訳：
  - `deferred_tools_delta` — 利用可能 tool 一覧の差分
  - `mcp_instructions_delta` — MCP server からの指示変化
  - `skill_listing` — skill 一覧の提示
  - `hook_additional_context` — hook が Claude に追加 context として渡したもの
  - `hook_success` — hook の成功通知
  - `todo_reminder` — TodoWrite 関連のリマインダ注入
- `summary` — session 要約。**通常は出ない**。compaction（PreCompact 後）が走った session の先頭等に後付け生成される。0 件の session が普通

### session メタデータ（uuid なし、parentUuid なし、会話には乗らない）

- `ai-title` — AI が生成した session の短タイトル。session 中に複数回再発行されうる（中身は同じことが多い）。`aiTitle` / `sessionId` / `type` のみ
- `last-prompt` — 直近 user prompt のスナップショット。`lastPrompt`（本文）と `leafUuid`（末端メッセージへの参照）。プロンプトが追加されるたびに発行される
- `queue-operation` — user prompt の input queue への出入り。`operation: enqueue`（`content` 同梱）/ `dequeue`（content なし）。`timestamp` はあるが uuid はない
- `permission-mode` — 現在の permission mode（`default` / `acceptEdits` / `bypassPermissions` / `plan` / `dontAsk` / `auto`）の記録。interactive 起動時や `/permissions` での切替で発行される
- `file-history-snapshot` — Claude Code が監視中のファイルの状態スナップショット。interactive 起動時に session 開始時の baseline として書かれることがある

### 注意

- **type ごとに必須フィールドが違う**。`uuid` / `parentUuid` / `timestamp` を全レコードに期待してパースすると `ai-title` `last-prompt` `queue-operation` で破綻する。型でフィルタしてから触る
- 会話の流れを再構成するなら、まず `user` `assistant` `system` `attachment` だけに絞ってから親子を辿るのが安全

## 読む順序

ログの全体像は events から、深掘りは transcript から、というのが基本。

### 全体像

```bash
# event 種別の出現数
jq -r '.event' events.jsonl | sort | uniq -c | sort -rn

# tool 使用の内訳
jq -r 'select(.event == "PreToolUse") | .payload.tool_name' events.jsonl | sort | uniq -c | sort -rn

# 時系列の主要点
jq -c '{ts, event, tool: .payload.tool_name // null}' events.jsonl
```

### 計画書との照合

session_id から該当する `.lathe/runs/pr-<n>/plans/<run_id>.html` を見つけ、これを Read する。計画書は orchestrator と人間の契約。実行が契約とどう乖離したかは、観察の出発点として強い。

session_id ↔ run_id の対応は events に出る Write tool_use(`.lathe/plans/<run_id>.html` への書き込み)で辿れる。

### 深掘り

events で気になる箇所を特定したら、ts を頼りに transcript の該当時刻を読む。

```bash
# 拡張思考の中身を見る
jq -c 'select(.message.content[]?.type == "thinking") | .message.content[].thinking' transcript.jsonl
```

## 突合

events と transcript は同じ session の別断面。基本的には：

- events の PreToolUse 数 ≒ transcript の tool_use 数
- ズレるなら、hook 不発、subagent 内の動き(hook によっては subagent と main で扱いが違う)、または transcript コピー時点の差(Stop コピーなので途中状態は含まない)が原因

## 気をつける点

- `summary`、`thinking` は一次情報ではない。「そう考えた」は事実だが「実際にそうだった」は別
- 計画書の内容も orchestrator の自己申告。自己評価は甘くなりうる
- 圧縮(PreCompact)が起きた session は、transcript 前半が summary に置き換わっており元情報が失われている
- 異常終了した session は transcript.jsonl がコピーされていない(Stop hook が走らないため)
- 1 run の出来事と複数 run のパターンは区別する。同じ事象が複数 session に出るかを確認する
