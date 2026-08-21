# Shshプロンプトのベンチマーク

## 目的

入力可能になるまでの時間と、非同期Git表示が完成するまでの時間を混同せずに測定する。ベンチマークでは次の4時点を分けて記録する。

1. 初期表示: 次の入力記号がterminalへ届くまで
2. branch表示: branchまたはdetached HEADを描画できるまで
3. Git状態完了: 詳細statusが表示へ反映されるまで
4. worker内Git計算: IPCと再描画を除いたworker内のstatus実行時間

ユーザー体験に最も強く影響する指標は初期表示である。Git状態完了はbackgroundで消費するCPUとI/Oの評価には必要だが、そのまま体感速度を表すものではない。

## 測定用リポジトリ

LLVMのshallow cloneを専用ディレクトリへ作成する。価値のある作業内容を含むリポジトリでは、ベンチマーク用の変更やcleanupを実行しない。

```sh
_prompt_bench_root="${TMPDIR%/}/prompt-benchmark"
_prompt_bench_repo="$_prompt_bench_root/llvm-project"

mkdir -p "$_prompt_bench_root"
git clone --depth=1 https://github.com/llvm/llvm-project.git "$_prompt_bench_repo"

git -C "$_prompt_bench_repo" rev-parse HEAD
git -C "$_prompt_bench_repo" count-objects -vH
git -C "$_prompt_bench_repo" rev-list --count HEAD
du -sh "$_prompt_bench_repo"
```

clean条件はclone直後の状態とする。dirty条件では、追跡済みファイルの変更と未追跡ファイルを1件ずつ作る。

```sh
printf '\n# prompt benchmark\n' >> "$_prompt_bench_repo/README.md"
: > "$_prompt_bench_repo/.prompt-benchmark-untracked"
git -C "$_prompt_bench_repo" status --short
```

測定後は、この使い捨てcloneだけを元へ戻す。

```sh
git -C "$_prompt_bench_repo" restore -- README.md
rm -- "$_prompt_bench_repo/.prompt-benchmark-untracked"
```

shallow cloneはindexとworktreeの走査を評価する用途には適しているが、長い履歴を対象とする処理は評価できない。ahead／behindなどの履歴依存処理を変更するときは、full cloneを別のworkloadとして追加する。

## 測定ハーネスの要件

一時的な`ZDOTDIR`とShshに必要な最小限の依存を使い、擬似terminal上で実際の対話Zshを起動する。`_shsh_render`だけを直接測る方法は、ZLE、prompt expansion、worker IPC、再描画を含まないため、microbenchmarkにしか使用しない。

ExpectなどのPTY driverを使用する。smoke testと複数回のwarm upを行った後、cleanとdirtyを最低30回ずつ測定する。最初の`❯`で次の試行へ進まず、branchとstatusの両callbackが届くまでZLEのevent loopを動かす。

Shshの関数をwrapして測定eventを追加してよいが、jobの実行順序を変えたり、1つの処理を分割したり、同期経路へ外部コマンドを追加したりしない。空のcallbackを使ってinstrumentation自体のcostも確認する。

ローカルGitの測定中は、`_shsh_maybe_fetch`を成功するno-opへ差し替える。network latencyは安定せず、fetchは別workerで動作するため、専用testへ分離する。この差し替えはproduction optionにせず、測定metadataへ記録する。

## イベントログ

1行に1件、次の形式で記録する。

```text
EVENT ITERATION TIMESTAMP DETAIL
```

時刻には`zsh/datetime`の`EPOCHREALTIME`を使用する。共通loggerは次のようにできる。

```zsh
zmodload zsh/datetime

_prompt_bench_log() {
  local event=$1 detail=${2-}
  print -r -- "$event $PROMPT_BENCH_ITERATION $EPOCHREALTIME $detail" \
    >> "$PROMPT_BENCH_LOG"
}
```

最低限、次を記録する。

| イベント | 記録位置 | 意味 |
|---|---|---|
| `START` | 測定コマンドから戻る直前 | 試行の基準時刻 |
| `RENDER` | 入力記号がPTYへ届いた時点 | 入力可能になった時刻 |
| `CALLBACK branch` | branch結果の受信時 | branchを表示できる時刻 |
| `CALLBACK status` | 詳細statusの受信時 | ローカルGit表示の完了時刻 |
| `WORKER status` | status jobの終了時 | IPCと再描画を除いたGit計算時間 |

試行`i`の対応する時刻または時間を`Sᵢ`、`Rᵢ`、`Bᵢ`、`Gᵢ`、`Wᵢ`とし、次を計算する。

```text
initial_promptᵢ = Rᵢ - Sᵢ
branch_visibleᵢ = Bᵢ - Sᵢ
git_completeᵢ   = Gᵢ - Sᵢ
worker_gitᵢ     = Wᵢ
```

各指標のsample数、median、mean、min、p95、maxをms単位で出す。主な比較にはmedianを使い、scheduler由来の外れ値を確認するためp95も併記する。timeoutした試行は欠測とし、timeout値を成功sampleへ混ぜない。

## 再現性のための記録

長期保存する測定では、harness、生event、terminal log、集計値、metadataを同じ場所へ保存する。

```text
docs/prompt/benchmark-results/YYYY-MM-DD/
├── metadata.md
├── harness/
├── events-clean.log
├── events-dirty.log
├── summary.json
├── terminal-clean.tty
└── terminal-dirty.tty
```

通常の確認では一時ディレクトリだけでよい。設計判断または性能回帰の根拠として再利用する測定だけをcommitする。

`metadata.md`には最低限次を記録する。

- OS、architecture、terminal、Zsh、Git、`zsh-async`のversion
- Shshのcommitとworktreeの変更有無
- リポジトリURL、commit、shallow depth、object数、pack size、worktree size
- clean／dirty状態の正確な作成方法
- `core.fsmonitor`、`core.untrackedCache`、関連するglobal／system Git設定
- warm up回数、測定回数、terminalの縦横、電源状態
- fetchを無効化または差し替えたか
- instrumentationによる変更と、その実測cost

revisionを比較する場合はこれらの条件を揃える。cold／warm sample、異なるLLVM commit、異なるdirty状態、異なるcache設定を同じ比較に混ぜない。

## 回帰判定

LLVM workloadでは、入力とbranch表示に次の固定基準を使用する。

| 指標 | 上限 |
|---|---:|
| 初期表示 median | 5 ms |
| 初期表示 p95 | 10 ms |
| branch表示 median | 25 ms |

Git状態完了はリポジトリ、filesystem、Git cacheに支配されるため、固定の絶対上限を設けない。Git処理量を意図的に変えていない修正では、同条件のbefore／afterを比較し、次の場合に原因を調べる。

- Git状態完了またはworker内Git計算のmedianが10%以上悪化した。
- worker完了からstatus反映までの差が10 msを超えた。
- 新しいtimeout、古い結果の混入、入力停止、再描画の破損が発生した。

性能確認には対話動作も含める。branchとstatusの更新中に、文字入力、履歴移動、補完、`Ctrl-C`、拡大・縮小方向のresizeを試す。再描画後も編集bufferとcursor位置を保持し、移動前のディレクトリから届いた結果を表示しないことを確認する。

## 現在の比較結果

最新のShshと、比較対象にしたprompt libraryの定常利用時の性能を同じPTY harnessで測定した。Typewrittenは`TYPEWRITTEN_PROMPT_LAYOUT=pure`を指定している。Powerlevel10kはLean設定を基に表示要素を揃え、起動後の`gitstatusd`がリポジトリ状態を保持した状態を測定した。

| 項目 | 値 |
|---|---|
| 測定日 | 2026-08-22 |
| OS | macOS 26.6.2、arm64 |
| Zsh | Apple Zsh 5.9 |
| Git | 2.55.0 |
| 電源 | AC接続 |
| PTY | `xterm-256color`、80×24 |
| リポジトリ | `llvm/llvm-project`のdepth 1 clone |
| リポジトリcommit | `6c206e3` |
| worktree | 約2.8 GB |
| pack | 293.55 MiB、191,166 objects |
| Git cache | `core.fsmonitor`、`core.untrackedCache`ともに未設定 |
| warm up | shell起動後2.5秒 |
| 測定回数 | clean／dirty各30回 |

測定対象のrevisionは次のとおり。

- Shsh: `e83d8f2`
- zsh-async: `ee1d11b`
- Pure: `89c9e30`
- Typewritten: `06f8575`
- Powerlevel10k: `3308262`

Shshの自動fetchは成功するno-opへ差し替え、Pureは`PURE_GIT_PULL=0`とした。network処理はどの測定にも含めていない。

単位はms、値はmedian / p95。取得対象の各指標でsample数は30であり、timeoutと欠測はなかった。

### Clean

| Prompt | 初期表示 | branch表示 | Git状態完了 | worker内Git計算 |
|---|---:|---:|---:|---:|
| Shsh | 1.961 / 2.189 | 11.837 / 12.733 | 488.697 / 493.291 | 485.728 / 490.400 |
| Pure | 0.877 / 1.033 | 84.509 / 125.187 | 495.492 / 540.235 | 492.274 / 498.898 |
| Typewritten Pure | 16.063 / 16.506 | 26.874 / 27.752 | 543.159 / 552.743 | 523.780 / 533.196 |
| Powerlevel10k Lean | 4.598 / 23.308 | 4.841 / 23.430 | 4.841 / 23.430 | — |

### Dirty

追跡済みの`README.md`を変更し、未追跡ファイルを1件追加した。

| Prompt | 初期表示 | branch表示 | Git状態完了 | worker内Git計算 |
|---|---:|---:|---:|---:|
| Shsh | 1.963 / 2.179 | 11.800 / 12.877 | 495.910 / 522.659 | 492.880 / 519.852 |
| Pure | 0.940 / 0.986 | 73.400 / 116.382 | 498.114 / 525.858 | 494.637 / 511.784 |
| Typewritten Pure | 15.993 / 16.657 | 26.852 / 27.932 | 543.012 / 587.019 | 523.230 / 566.673 |
| Powerlevel10k Lean | 4.447 / 24.050 | 4.650 / 24.332 | 4.650 / 24.332 | — |

### 比較

- **Shsh**
  - 初期表示は約2 msで、回帰判定の5 msを十分に下回る。
  - 毎回新しいGit jobを実行する3実装ではbranch表示が約12 msで最も速い。
  - Git状態完了は約0.49秒、worker完了から表示反映までの差はclean、dirtyとも約3 msだった。
- **Pure**
  - 初期表示が最も速く、medianは1 ms未満だった。
  - branch表示は約73〜85 ms、Git状態完了は約0.50秒で、詳細statusの性能はShshとほぼ同等だった。
- **Typewritten Pure**
  - `precmd`でGit設定とリポジトリを同期判定してから描画するため、初期表示は約16 msだった。
  - Git状態完了は約0.54秒で、毎回Git jobを実行する3実装の中では最も遅い。
- **Powerlevel10k Lean**
  - `gitstatusd`が保持した状態を同じprompt描画で利用するため、branchと詳細statusを約5 msで表示した。
  - 各試行で独立したstatus scanを行わないためworker内Git計算は該当せず、他3実装のworker実行時間とは直接比較できない。
  - daemon起動直後のcold性能もこの測定には含まない。

Shsh、Pure、TypewrittenではGit statusを非同期に実行するため、Git状態完了までの時間は入力開始を妨げない。

最終的に、定常状態のGit表示速度はPowerlevel10kが明確に最速である。Shshはdaemonを持たず標準Gitとzsh-asyncだけを使う構成のまま、Pureに近い初期応答と、Pure／Typewrittenより早いbranch表示を実現している。保守性を優先する現在の設計に対して、性能上の大きな不足は見られない。

## 自動fetchのテスト

fetchのscheduleはローカルlatencyとは別に測定する。約400 msかかる決定的なworker関数を使用し、50 ms間隔でpromptを10回更新する。期待する結果は次のとおり。

- 同じリポジトリでfetch jobが1回だけqueueへ入る。
- ローカルrefreshがそのjobをcancelしない。
- jobが1回完了する。
- 5分のinterval内に2回目をqueueしない。
- foreground fetchはnetwork workerだけをcancelする。

性能回帰の比較には実remoteを使用しない。非対話の認証失敗を確認するsmoke testでは実remoteを使用してよいが、remote、network条件、rate limitの状態を記録する。

## Gitキャッシュの効果

Shshは常に未追跡ファイルを取得する。prompt独自の除外設定やstale dirty cacheではなく、GitのFSMonitorとuntracked cacheを使ってstatus自体を高速化する設計である。

### Git status

比較と同じclean状態のLLVM cloneで測定した。Shshが実行する次のstatusを基準とし、未追跡だけを`no`へ変えたものと比較した。

```sh
GIT_OPTIONAL_LOCKS=0 git status \
  --porcelain=v2 --show-stash --untracked-files=normal --no-renames
```

cacheごとに通常のstatusでindexを初期化し、組み込みFSMonitor daemonの動作を確認してから、Hyperfineで5回warm up、30回測定した。単位はms、値はmedian / p95。

| Git設定 | 未追跡を含むstatus | 未追跡を除外したstatus |
|---|---:|---:|
| cacheなし | 469.903 / 476.285 | 132.780 / 133.900 |
| FSMonitorのみ | 365.449 / 369.763 | 28.442 / 28.831 |
| FSMonitor + untracked cache | 42.545 / 43.022 | 29.160 / 29.487 |

FSMonitorは追跡済みファイルの確認を約29 msまで短縮するが、未追跡ディレクトリの走査は高速化しない。untracked cacheを併用すると、未追跡を含むstatusは469.903 msから42.545 msへ約11倍高速になり、未追跡を除外した場合との差は約13 msまで縮まった。

### Shsh全体

FSMonitorとuntracked cacheを有効にしたまま、同じPTY harnessでShshをclean／dirty各30回測定した。単位はms、値はmedian / p95。

| 状態 | 初期表示 | branch表示 | Git状態完了 | worker内Git計算 |
|---|---:|---:|---:|---:|
| Clean | 2.198 / 2.392 | 14.045 / 15.363 | 50.454 / 63.291 | 47.148 / 59.929 |
| Dirty | 2.192 / 2.528 | 13.797 / 14.882 | 54.379 / 55.753 | 51.094 / 52.437 |

cacheなしのGit状態完了は約489〜496 msだったため、cacheの併用で約50〜54 msまで短縮した。Powerlevel10kの約5 msには及ばないが、入力は約2 ms、branchは約14 msで表示され、詳細statusも非同期で約50 ms後に完成する。組み込みFSMonitorを利用できるローカルfilesystemでは、標準Gitだけでも大規模リポジトリの対話利用に十分な性能と判断できる。

この結果はcacheがwarmな定常状態を示す。最初のindex走査、filesystemがFSMonitorを提供しない環境、network filesystemでは同じ性能を期待できない。

利用前にuntracked cacheの対応を確認し、対象リポジトリへ設定する。

```sh
git -C "$_prompt_bench_repo" update-index --test-untracked-cache
git -C "$_prompt_bench_repo" config --local core.fsmonitor true
git -C "$_prompt_bench_repo" config --local core.untrackedCache true
git -C "$_prompt_bench_repo" status --short
```

ベンチマークでは使い捨てcloneだけに設定する。測定後は設定とindex extensionを戻し、組み込みFSMonitor daemonを停止する。
