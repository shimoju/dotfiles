# Zshプロンプトのベンチマーク

## 目的

巨大なGitリポジトリで、次の時間を分離して測定する。

1. コマンド終了後、次の入力を開始できるまで
2. Gitブランチが表示されるまで
3. dirtyを含むGit状態が揃うまで
4. バックグラウンドでのGit計算そのものの実行時間

プロンプト全体の処理が完了するまでの時間だけを測ると、Pureのように入力を先に受け付け、Git情報を後から更新するプロンプトの体感速度を表現できない。そのため、初期表示と非同期更新を別のイベントとして記録する。

## 今回の測定環境

測定日: 2026-08-12

| 項目 | 値 |
|---|---|
| OS | macOS、arm64 |
| Zsh | 5.9 |
| Git | 2.55.0 |
| Pure | 1.28.3 |
| 測定回数 | clean／dirtyそれぞれ15回 |
| リポジトリ | `llvm/llvm-project`のshallow clone |
| 作業ツリー | 約2.9 GB |
| pack | 約294 MiB、190,623 objects |
| 履歴 | `--depth=1`、1 commit |

shallow cloneなので、長いコミット履歴を走査する処理の評価には向かない。一方、今回支配的だったindexと作業ツリーの走査を比較する用途には適している。

## リポジトリの準備

専用の使い捨てディレクトリにcloneする。以下の変更・復元コマンドは、この専用clone以外では実行しない。

```sh
_prompt_bench_root="${TMPDIR%/}/prompt-benchmark"
_prompt_bench_repo="$_prompt_bench_root/llvm-project"

mkdir -p "$_prompt_bench_root"
git clone --depth=1 https://github.com/llvm/llvm-project.git "$_prompt_bench_repo"

git -C "$_prompt_bench_repo" count-objects -vH
git -C "$_prompt_bench_repo" rev-list --count HEAD
du -sh "$_prompt_bench_repo"
```

clean条件はclone直後の状態とする。

dirty条件では、追跡済みファイルの変更と未追跡ファイルを1つずつ作る。Pureの詳細dirty表示では`*?`になる状態である。

```sh
printf '\n# prompt benchmark\n' >> "$_prompt_bench_repo/llvm/CMakeLists.txt"
: > "$_prompt_bench_repo/.prompt-benchmark-untracked"
git -C "$_prompt_bench_repo" status --short
```

測定後に専用cloneをcleanへ戻す場合:

```sh
git -C "$_prompt_bench_repo" restore -- llvm/CMakeLists.txt
rm -- "$_prompt_bench_repo/.prompt-benchmark-untracked"
```

## 測定方法

### 1. 実際の対話Zshを使う

`zsh -dfi`を擬似端末上で起動し、各プロンプトに必要な最小設定だけを読み込む。非対話シェルで関数を直接呼ぶ測定は、ZLEによる再描画や非同期callbackのコストを含まないため使用しない。

Expectなどで擬似端末を操作し、初期プロンプトの確認後に測定コマンドを15回送る。最初にsmoke testとウォームアップを行い、ウォームアップの結果は集計しない。

### 2. イベントを単調な形式で記録する

ログは1行1イベントとし、最低限次の形式にする。

```text
EVENT ITERATION TIMESTAMP DETAIL
```

例:

```text
START 1 1786540000.123456
RENDER 1 1786540000.126520
CALLBACK 1 1786540000.201721 branch exec=0.070
CALLBACK 1 1786540000.634422 dirty exec=0.502
```

時刻にはZshの`EPOCHREALTIME`を使う。共通のログ関数は次の形にできる。

```zsh
zmodload zsh/datetime

_prompt_bench_log() {
  local event=$1 detail=${2-}
  print -r -- "$event $PROMPT_BENCH_ITERATION $EPOCHREALTIME $detail" \
    >> "$PROMPT_BENCH_LOG"
}
```

### 3. 記録するイベント

| イベント | 記録位置 | 意味 |
|---|---|---|
| `START` | 測定用コマンドの先頭 | コマンド終了から次のプロンプトを作り始める基準 |
| `RENDER` | 同期部分の描画直前 | ユーザーが入力を開始できる時点 |
| `CALLBACK branch` | ブランチ結果の受信時 | ブランチが表示可能になった時点 |
| `CALLBACK dirty` | dirty結果の受信時 | ローカルGit状態が揃った時点 |
| `WORKER` | worker内の処理終了時 | IPCと再描画を除いた計算時間 |

Pureでは`prompt_pure_preprompt_render`と`prompt_pure_async_callback`を測定用設定からラップしてイベントを記録した。自作プロンプトでは、描画関数とworker callbackへ直接ログを入れる。

Git情報を一括で返す実装では`branch`と`dirty`が同じ時刻になる。段階表示しない実装に、存在しない中間イベントを作らない。

### 4. 非同期完了までZLEを動かす

最初の`❯`が出た時点で次の試行へ移らず、対象のcallbackが記録されるまで待つ。必要なら、入力内容を変えない`x`、Backspaceの組を擬似端末へ送り、ZLEのイベントループを継続させる。

試行ごとにtimeoutを設け、timeoutした試行は欠測として成功試行と混ぜない。

### 5. 生データを保存する

今回の一時ログは`/tmp`の消去により残っていない。次回からは次をGit管理対象の結果ディレクトリへ保存する。

```text
docs/prompt-benchmark-results/YYYY-MM-DD/
├── metadata.md
├── events-clean.log
├── events-dirty.log
├── summary.json
├── terminal-clean.tty
└── terminal-dirty.tty
```

`metadata.md`にはOS、CPU、Zsh、Git、プロンプトのcommit、リポジトリのcommit、Git設定、dirtyの作り方を記録する。

## 集計方法

試行`i`の時刻を次のように定義する。

- `Sᵢ`: `START`
- `Rᵢ`: 最初の`RENDER`
- `Bᵢ`: ブランチを反映したcallback
- `Gᵢ`: dirtyを反映したcallback
- `Wᵢ`: workerが報告したGit計算時間

集計値は次の差分で求める。

```text
initial_promptᵢ = Rᵢ - Sᵢ
branch_visibleᵢ = Bᵢ - Sᵢ
git_completeᵢ   = Gᵢ - Sᵢ
worker_gitᵢ     = Wᵢ
```

各指標について、試行数、median、mean、min、p95、maxをミリ秒で出す。主比較には外れ値の影響を受けにくいmedianを使い、p95とmaxも併記する。

## 今回の結果

### 中央値

| 実装・状態 | 初期表示 | ブランチ表示 | Git状態完了 | worker内Git計算 |
|---|---:|---:|---:|---:|
| Pure clean | 3.034 ms | 78.085 ms | 508.858 ms | 500.033 ms |
| Pure dirty (`*?`) | 3.064 ms | 78.265 ms | 510.966 ms | 502.496 ms |
| git-prompt.zsh試作 | 約8 ms | 一括表示 | 約496 ms | 約496 ms |

git-prompt.zsh試作の値は当時の要約から復元した概算であり、下の詳細統計には含めない。

### Pure clean、15回

| 指標 | median | mean | min | p95 | max |
|---|---:|---:|---:|---:|---:|
| 初期表示 | 3.034 | 3.049 | 2.310 | 3.893 | 3.893 |
| ブランチ表示 | 78.085 | 86.389 | 49.256 | 133.997 | 133.997 |
| Git状態完了 | 508.858 | 508.067 | 500.496 | 513.270 | 513.270 |
| worker内Git計算 | 500.033 | 499.477 | 493.558 | 505.136 | 505.136 |

単位はms。

### Pure dirty、15回

| 指標 | median | mean | min | p95 | max |
|---|---:|---:|---:|---:|---:|
| 初期表示 | 3.064 | 3.235 | 2.742 | 3.982 | 3.982 |
| ブランチ表示 | 78.265 | 89.620 | 50.041 | 133.021 | 133.021 |
| Git状態完了 | 510.966 | 514.880 | 505.397 | 569.315 | 569.315 |
| worker内Git計算 | 502.496 | 506.292 | 497.679 | 560.335 | 560.335 |

単位はms。

## 解釈

- 約500 msかかるGit状態の完了を待たず、約3 msで入力可能になっている。これがPureの体感速度の中心である。
- ブランチは約78 msで先に表示され、dirtyは約509–511 msで後から追加される。自作版でも段階表示を維持したい。
- cleanとdirtyで初期表示はほぼ変わらない。Gitの重さがZLEの入力開始から切り離されている。
- cleanでもdirty判定は約500 msかかるため、「変更がない場合だけ速い」リポジトリではない。
- `git status`系の計算時間はPureとgit-prompt.zsh試作で同程度だった。自作の主眼はGit自体を劇的に速くすることより、待ち時間を入力経路から外すことになる。
- 自動fetchは非同期なので入力開始を妨げない。ただしネットワーク完了時間はこの`Git状態完了`指標に含めず、CPU、I/O、通信量は別途評価する。

## 自作プロンプトを追加するときの合格基準

| 指標 | 目標 |
|---|---:|
| 初期表示 median | 5 ms以下 |
| 初期表示 p95 | 10 ms以下 |
| ブランチ表示 median | Pureの1.25倍以内 |
| Git状態完了 median | Pureの1.25倍以内 |
| コマンド入力の阻害 | なし |
| `cd`後の古い結果混入 | なし |
| worker異常時 | Git表示なしで入力継続 |

結果表へ次の行を追加する。

```markdown
| 自作 clean | TODO | TODO | TODO | TODO |
| 自作 dirty (`*?`) | TODO | TODO | TODO | TODO |
```

速度だけでなく、実行中に文字入力、履歴移動、補完、`Ctrl-C`を試し、非同期再描画が編集バッファやカーソル位置を壊さないことも確認する。

## 比較時の注意

- 同じLLVM clone、同じdirty状態、同じGit設定を使う。
- 最初のcold runとウォームアップ済みの結果を混ぜない。
- 自動fetchの有無をmetadataに書く。ネットワーク時間をローカルGit状態の指標へ混ぜない。
- `GIT_OPTIONAL_LOCKS=0`など、実装が設定する環境変数を記録する。
- untrackedを含めるか、詳細dirtyを使うかを統一する。
- 非同期プロンプトと同期プロンプトを「全表示完了」だけで比較しない。
- ベンチマーク用instrumentation自体のコストを、空のcallbackで測っておく。
