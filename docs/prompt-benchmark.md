# Zshプロンプトのベンチマーク

## 目的

巨大なGitリポジトリで、次の時間を分離して測定する。

1. コマンド終了後、次の入力を開始できるまで
2. Gitブランチが表示されるまで
3. dirtyを含むGit状態が揃うまで
4. バックグラウンドでのGit計算そのものの実行時間

プロンプト全体の処理が完了するまでの時間だけを測ると、Pureのように入力を先に受け付け、Git情報を後から更新するプロンプトの体感速度を表現できない。そのため、初期表示と非同期更新を別のイベントとして記録する。

## 今回の測定環境

測定日: 2026-08-19

| 項目 | 値 |
|---|---|
| OS | macOS 26.6.2、arm64 |
| Zsh | 5.9 |
| Git | 2.55.0 |
| Pure | 1.28.3、commit `89c9e30` |
| Geometry | commit `0f82c56` |
| Typewritten | 1.5.2、commit `06f8575` |
| 測定回数 | clean／dirtyそれぞれ15回 |
| リポジトリ | `llvm/llvm-project`のshallow clone |
| リポジトリcommit | `6c206e3` |
| 作業ツリー | 約2.9 GB |
| pack | 293.55 MiB、191,166 objects |
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
printf '\n# prompt benchmark\n' >> "$_prompt_bench_repo/README.md"
: > "$_prompt_bench_repo/.prompt-benchmark-untracked"
git -C "$_prompt_bench_repo" status --short
```

測定後に専用cloneをcleanへ戻す場合:

```sh
git -C "$_prompt_bench_repo" restore -- README.md
rm -- "$_prompt_bench_repo/.prompt-benchmark-untracked"
```

## 測定方法

### 1. 実際の対話Zshを使う

`ZDOTDIR`を測定用ディレクトリへ向けた`zsh -d -i`を擬似端末上で起動し、各プロンプトに必要な最小設定だけを読み込む。非対話シェルで関数を直接呼ぶ測定は、ZLEによる再描画や非同期callbackのコストを含まないため使用しない。

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

PureとTypewrittenではasync callbackを測定用設定からラップした。Geometryでは`geometry::rprompt::set`をラップした。初期表示は実際の`PROMPT`末尾へ端末制御シーケンスを追加し、それが擬似端末へ到達した時刻をExpect側で記録した。自作プロンプトでは、同じ位置へ計測点を追加する。

Git情報を一括で返す実装では`branch`と`dirty`が同じ時刻になる。段階表示しない実装に、存在しない中間イベントを作らない。

### 4. 非同期完了までZLEを動かす

最初の`❯`が出た時点で次の試行へ移らず、対象のcallbackが記録されるまで待つ。必要なら、入力内容を変えない`x`、Backspaceの組を擬似端末へ送り、ZLEのイベントループを継続させる。

試行ごとにtimeoutを設け、timeoutした試行は欠測として成功試行と混ぜない。

### 5. 生データを保存する

今回のハーネス、イベントログ、端末ログ、集計JSONは次の一時ディレクトリに保存した。

```text
/private/tmp/prompt-compare-20260819/harness/
```

一時ディレクトリはOSにより消去されるため、長期保存する測定では次をGit管理対象の結果ディレクトリへ保存する。

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

## 比較条件

- Pureは現在の設定と同じく、詳細dirtyとstashを有効、virtualenvとNixを無効にした。
- Pureの自動fetchだけはネットワーク揺らぎをローカルGit状態の比較へ混ぜないため、測定中のみ`PURE_GIT_PULL=0`とした。
- GeometryとTypewritten通常レイアウトはデフォルト設定を使った。
- Typewritten Pureレイアウトは`TYPEWRITTEN_PROMPT_LAYOUT=pure`だけを追加した。
- GeometryはGit情報を右プロンプトの1ジョブでまとめて返すため、独立したブランチ表示時間とworker内Git計算時間を記録できない。

## 今回の結果

すべて15回の測定。単位はms。`—`はその実装に独立した計測点がないことを示す。

### Clean

| 実装 | 初期表示 median / p95 | ブランチ表示 median / p95 | Git状態完了 median / p95 | worker内Git計算 median / p95 |
|---|---:|---:|---:|---:|
| Pure | 0.927 / 1.700 | 71.583 / 119.023 | 495.530 / 544.461 | 491.690 / 497.967 |
| Geometry | 13.904 / 22.175 | — | 829.090 / 866.114 | — |
| Typewritten default | 16.708 / 31.010 | 27.842 / 50.044 | 545.852 / 763.199 | 525.417 / 726.512 |
| Typewritten `pure` | 16.644 / 31.872 | 27.891 / 50.673 | 544.943 / 780.446 | 524.516 / 743.121 |

### Dirty

追跡済みファイルの変更と未追跡ファイルが1つずつある状態。

| 実装 | 初期表示 median / p95 | ブランチ表示 median / p95 | Git状態完了 median / p95 | worker内Git計算 median / p95 |
|---|---:|---:|---:|---:|
| Pure | 0.860 / 2.092 | 69.661 / 123.845 | 491.888 / 533.214 | 488.134 / 499.109 |
| Geometry | 13.612 / 22.480 | — | 340.386 / 352.301 | — |
| Typewritten default | 16.226 / 28.275 | 27.096 / 45.878 | 544.338 / 761.721 | 524.034 / 718.238 |
| Typewritten `pure` | 16.530 / 34.066 | 27.353 / 51.498 | 544.290 / 776.590 | 523.997 / 724.258 |

Typewrittenの通常レイアウトとPureレイアウトの差は測定揺らぎの範囲であり、`TYPEWRITTEN_PROMPT_LAYOUT=pure`による有意な性能低下は見られなかった。

## 解釈

- 約500 msかかるGit状態の完了を待たず、Pureは中央値1 ms未満で入力可能になっている。これがPureの体感速度の中心である。
- Pureのブランチは約70–72 msで先に表示され、dirtyは約492–496 msで後から追加される。自作版でも段階表示を維持したい。
- cleanとdirtyで初期表示はほぼ変わらない。Gitの重さがZLEの入力開始から切り離されている。
- Typewrittenはブランチを約27–28 msで表示し、この指標だけならPureより速い。一方、同期処理を含む初期表示は約16–17 ms、Git状態完了は約544–546 msだった。
- GeometryのGit表示は段階表示されない。cleanでは約829 ms、追跡済みdirtyでは約340 msとなった。これはdirty時に`git diff-index --quiet HEAD`で短絡し、clean時には続けて`git status --porcelain --ignore-submodules`を実行する実装による。未追跡だけのdirtyも後段まで進むため、このdirty値を一般化しない。
- 自作の主眼はGit自体を劇的に速くすることより、待ち時間を入力経路から外し、軽い情報から段階的に表示することになる。
- 自動fetchは非同期なので入力開始を妨げない。ただしネットワーク完了時間はこの`Git状態完了`指標に含めず、CPU、I/O、通信量は別途評価する。

機能と実装方式を含む評価は[Pure・Geometry・Typewrittenの比較](prompt-comparison.md)を参照。

## Git標準の高速化機能

未追跡ファイルを除外するとGit状態は速くなるが、プロンプトから`?`が欠落する。完全な状態を維持したまま高速化できるか、同じLLVM cloneでGit組み込み[FSMonitor](https://git-scm.com/docs/git-fsmonitor--daemon)と[untracked cache](https://git-scm.com/docs/git-status.html#_untracked_files_and_performance)を比較した。

```sh
git config --local core.fsmonitor true
git config --local core.untrackedCache true
```

各設定を有効にして数回の`git status`でcacheをウォームアップした後、`GIT_OPTIONAL_LOCKS=0`付きで15回測定した。単位はms。

| Git設定 | 未追跡を含むstatus mean | 未追跡除外status mean |
|---|---:|---:|
| FSMonitorなし、untracked cacheなし | 475.0 | 136.4 |
| FSMonitorのみ | 366.6 | 30.6 |
| FSMonitor + untracked cache | 44.8 | 31.2 |

FSMonitorだけでも、追跡済み182,241ファイルへの`lstat`を中心とする処理は136.4 msから30.6 msへ短縮した。一方、未追跡を含むstatusは366.6 ms残り、未追跡ディレクトリの探索が支配的になった。

untracked cacheを併用すると、未追跡を含む完全statusは44.8 msまで短縮した。未追跡除外との差は約14 msなので、自作プロンプトには未追跡除外設定とslow dirty cacheを設けず、常に完全で最新の状態を非同期取得する。巨大リポジトリではGit側で両機能を有効にする。

FSMonitorはローカルの対応ファイルシステムを前提とし、cacheはウォームアップを必要とする。この測定では使い捨てcloneだけに設定し、測定後にdaemonを停止して設定とindex extensionを元へ戻した。

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
- `core.fsmonitor`と`core.untrackedCache`の有無、cacheのウォームアップ状態を記録する。
- untrackedを含めるか、詳細dirtyを使うかを統一する。
- 非同期プロンプトと同期プロンプトを「全表示完了」だけで比較しない。
- ベンチマーク用instrumentation自体のコストを、空のcallbackで測っておく。
