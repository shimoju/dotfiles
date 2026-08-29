# Shshプロンプトのベンチマーク

## 目的

入力可能になるまでの時間と、非同期Git表示が完成するまでの時間を分けて測定する。また、次の2種類の初期表示を混同しない。

- 初期表示: 起動済みの対話Zshで、コマンド終了から次の入力記号を表示するまで
- fresh-process startup: 新しい対話Zshをspawnする直前から、最初の入力プロンプトを完全に表示するまで

Gitについてはbranch表示と詳細status完了も別に記録する。体感速度には初期表示とfresh-process startupが最も強く影響し、Git状態完了はbackgroundのCPU・I/O負荷を評価する指標となる。

## 測定用リポジトリ

LLVMのdepth 1 cloneを、価値のある作業内容を含まない専用ディレクトリへ作成する。

```sh
_prompt_bench_root="${TMPDIR%/}/prompt-benchmark"
_prompt_bench_repo="$_prompt_bench_root/llvm-project"

mkdir -p "$_prompt_bench_root"
git clone --depth=1 https://github.com/llvm/llvm-project.git "$_prompt_bench_repo"
git -C "$_prompt_bench_repo" branch -m prompt-benchmark

git -C "$_prompt_bench_repo" rev-parse HEAD
git -C "$_prompt_bench_repo" count-objects -vH
du -sh "$_prompt_bench_repo"
```

clean条件はclone直後の状態とする。通常dirty条件では追跡済みファイルと未追跡ファイルを1件ずつ変更する。

```sh
printf '\n# prompt benchmark\n' >> "$_prompt_bench_repo/README.md"
: > "$_prompt_bench_repo/.prompt-benchmark-untracked"
```

大量dirty条件では、modeが`100644`の追跡済みファイル5,500件をindex上で`100755`へ変更する。

```sh
git -C "$_prompt_bench_repo" ls-files -s |
  awk '$1 == "100644" { sub(/^[^\t]*\t/, ""); print; if (++n == 5500) exit }' |
  git -C "$_prompt_bench_repo" update-index --chmod=+x --stdin
```

測定後は使い捨てcloneだけを復元する。

```sh
git -C "$_prompt_bench_repo" restore -- README.md
rm -- "$_prompt_bench_repo/.prompt-benchmark-untracked"

git -C "$_prompt_bench_repo" diff --cached --name-only |
  git -C "$_prompt_bench_repo" update-index --chmod=-x --stdin
```

shallow cloneはindexとworktreeの走査用であり、長い履歴を使う処理の評価には適さない。ahead／behindなどを変更するときはfull cloneを別workloadとして追加する。

## fresh-process startup

### 測定方法

`tests/prompt/benchmark_startup.zsh`はExpectで実PTYを作り、sampleごとに`env -i /bin/zsh -d -i`を起動する。通常の`.zshrc`やplugin managerは読み込まず、promptのsource、初期化、最初のworker生成は測定に含める。

最初のプロンプト末尾へ不可視markerを付け、PTYで受信した直後に1文字送信する。そのechoを確認して`Ctrl-U`で消すことで、ZLEが入力可能になったことも検証する。Gitリポジトリではbranch文字列とstatus callbackのmarkerまで待つ。

固定revisionの比較対象を用意し、次のように実行する。

```sh
export PROMPT_BENCH_ASYNC_PATH=/path/to/zsh-async/async.zsh
export PROMPT_BENCH_PURE_ROOT=/path/to/pure
export PROMPT_BENCH_TYPEWRITTEN_ROOT=/path/to/typewritten
export PROMPT_BENCH_P10K_ROOT=/path/to/powerlevel10k
export PROMPT_BENCH_GITSTATUS_CACHE=/path/to/gitstatus-cache

zsh tests/prompt/benchmark_startup.zsh \
  "$_prompt_bench_repo" \
  "${TMPDIR%/}/shsh-startup-results" \
  50 5
```

引数はcleanなGitリポジトリ、存在しない出力先、sample数、warm up数である。出力先にはsample単位の`events.tsv`、集計済みの`summary.tsv`、PTY出力の`terminal.tty`が作られる。

比較対象と非Git／Git条件の順序はsampleごとに反転する。特定対象だけを確認する場合は、空白区切りの`PROMPT_BENCH_VARIANTS`を指定する。

```sh
PROMPT_BENCH_VARIANTS='bare_a shsh' \
  zsh tests/prompt/benchmark_startup.zsh \
  "$_prompt_bench_repo" \
  "${TMPDIR%/}/shsh-startup-smoke" \
  3 1
```

bare Zshは同一実装のA／A測定を含む。`bare_direct`はprecmd hookを使わずmarkerをPROMPTへ直接埋め込み、instrumentationのcostを確認する。filesystem cacheは消去せず、Zsh processだけを毎回新しくする。

### 結果

測定条件はmacOS 26.6.2 arm64、Apple Zsh 5.9、Git 2.55.0、AC接続、`xterm-256color` 80×24である。LLVMはcommit `6c206e3`、191,166 objects、約2.8 GiBで、FSMonitorとuntracked cacheは未設定。各条件で5回warm up後に50回測定し、timeoutはなかった。自動fetchは測定から除外した。

測定対象のrevisionは次のとおり。

- Shsh: `f4a26ce`
- zsh-async: `ee1d11b`
- Pure: `89c9e30`
- Typewritten: `06f8575`
- Powerlevel10k: `3308262`
- gitstatusd: 1.5.4

単位はms、値はmedian / p95。

| Prompt | 非Gitで初回表示 | Gitで初回表示 | first branch | first Git status |
|---|---:|---:|---:|---:|
| bare Zsh | 12.190 / 14.481 | 12.279 / 13.681 | — | — |
| Shsh | 22.861 / 25.657 | 23.831 / 26.466 | 31.381 / 35.399 | 512.446 / 582.175 |
| Pure | 26.107 / 28.175 | 26.872 / 29.248 | 57.577 / 63.879 | 552.996 / 593.812 |
| Typewritten Pure | 46.963 / 52.503 | 96.763 / 149.452 | 162.800 / 185.007 | 735.831 / 786.419 |
| Powerlevel10k Lean | 34.807 / 39.066 | 45.665 / 50.940 | 584.634 / 616.802 | 584.634 / 616.802 |

bare Zshに対する初回表示のmedian差は次のとおり。

| Prompt | 非Git | Git |
|---|---:|---:|
| Shsh | +10.671 | +11.552 |
| Pure | +13.917 | +14.593 |
| Typewritten Pure | +34.773 | +84.484 |
| Powerlevel10k Lean | +22.617 | +33.386 |

bare A／Aのmedian差は0.05 ms未満、marker方式の差は0.1 ms未満だった。実装間の差は測定系のnoiseを上回る。

- Shshは非bare実装で初回表示とbranch表示が最も速く、初回表示から約0.2 ms以内に入力を受け付けた。
- Shshの約11 msにはtheme setup、`promptinit`、最初のprecmd、zsh-async worker初期化、Kubernetes signature確認、右寄せ描画が含まれる。worker初期化の遅延やtheme規約の迂回は数msの短縮に対して複雑性が増すため採用しない。
- Pureの初回表示はShshより約3 ms遅く、汎用の`vcs_info`を使うbranch表示は約26 ms遅い。詳細statusは入力を妨げない。
- TypewrittenはGit設定とrepository rootを同期判定するため、LLVM内の初回表示が遅くp95の振れも大きい。
- Powerlevel10kはZshごとにgitstatusdを起動し、最初のscanでbranchとstatusを同時に得る。起動済みdaemonが状態を保持した定常測定とは性質が異なる。

5,500件のdirty fileを追加しても、ShshのGit内初回表示は23.323 / 24.674 ms、branchは30.780 / 32.680 msだった。dirty件数は非同期statusの時間には影響するが、fresh-process startupを支配しない。

## 起動済みシェルの参考値

同じ対話Zsh内で、次のプロンプトを表示する定常利用時の結果である。測定条件は2026-08-23、LLVM `6c206e3`、Git cache未設定、各条件30回。Shshは`850e443`、比較対象はfresh-process startupと同じrevisionを使用した。

単位はms、値はmedian / p95。

| 状態 | Prompt | 初期表示 | branch表示 | Git状態完了 | worker内Git計算 |
|---|---|---:|---:|---:|---:|
| Clean | Shsh | 1.803 / 2.001 | 11.575 / 12.794 | 491.994 / 498.566 | 488.917 / 495.114 |
| Clean | Pure | 0.862 / 1.005 | 131.568 / 139.640 | 498.179 / 541.663 | 494.683 / 505.761 |
| Clean | Typewritten Pure | 16.192 / 17.136 | 27.114 / 28.504 | 543.038 / 547.751 | 523.374 / 527.591 |
| Clean | Powerlevel10k Lean | 4.293 / 12.294 | 4.477 / 12.531 | 4.477 / 12.531 | — |
| Dirty | Shsh | 1.825 / 2.060 | 11.566 / 12.348 | 492.334 / 511.436 | 489.512 / 508.567 |
| Dirty | Pure | 0.914 / 0.970 | 132.434 / 139.788 | 497.453 / 501.641 | 493.828 / 498.211 |
| Dirty | Typewritten Pure | 16.160 / 17.612 | 27.514 / 30.125 | 544.688 / 551.120 | 524.715 / 531.097 |
| Dirty | Powerlevel10k Lean | 4.077 / 18.435 | 4.283 / 18.608 | 4.283 / 18.608 | — |
| 5,500 dirty | Shsh | 1.863 / 2.030 | 11.649 / 12.725 | 527.290 / 538.159 | 524.479 / 533.659 |
| 5,500 dirty | Pure | 0.854 / 1.014 | 129.077 / 137.523 | 521.510 / 527.759 | 517.599 / 521.704 |
| 5,500 dirty | Typewritten Pure | 16.041 / 16.460 | 26.952 / 28.160 | 568.070 / 573.033 | 548.295 / 553.657 |
| 5,500 dirty | Powerlevel10k Lean | 4.906 / 22.712 | 5.075 / 23.169 | 5.075 / 23.169 | — |

Powerlevel10kは状態を保持するgitstatusdにより定常Git表示が最速である。Shshは標準Gitとzsh-asyncだけを使い、約1.8 msで入力を返し、branchを約12 msで先行表示する。詳細statusは約0.5秒かかるが入力を妨げない。

## 回帰基準

Git cache未設定のLLVMで次を上限とする。

| 対象 | 指標 | 上限 |
|---|---|---:|
| 起動済みシェル | 初期表示 median | 3 ms |
| 起動済みシェル | 初期表示 p95 | 5 ms |
| 起動済みシェル | branch表示 median | 20 ms |
| 起動済みシェル | 大量dirtyのworker内Git計算 median | 600 ms |
| fresh process | 初回表示 median | 30 ms |
| fresh process | 初回表示 p95 | 35 ms |
| fresh process | 入力受付 median | 30 ms |
| fresh process | first branch median | 40 ms |

Git状態完了はfilesystemとGit cacheに支配されるため固定上限を設けない。Git処理量を変えていない修正でmedianが10%以上悪化した場合、またはworker完了から表示反映までが10 msを超えた場合は原因を調べる。bare A／Aのmedian差が0.5 msを超える場合は、Shshより先に測定環境を確認する。

性能に関わる変更では文字入力、履歴移動、補完、`Ctrl-C`、directory移動、連続resizeも確認する。非同期再描画後もbufferとcursorを維持し、移動前の結果を表示しないことを条件とする。

## Gitキャッシュの参考値

Shshは未追跡ファイルを常に取得し、独自のslow dirty cacheを持たない。大規模リポジトリではGit標準のFSMonitorとuntracked cacheを使用する。

```sh
git -C "$_prompt_bench_repo" update-index --test-untracked-cache
git -C "$_prompt_bench_repo" config --local core.fsmonitor true
git -C "$_prompt_bench_repo" config --local core.untrackedCache true
git -C "$_prompt_bench_repo" status --short
```

同じclean LLVMで5回warm up後に30回測定した結果。単位はms、値はmedian / p95。

| Git設定 | 未追跡を含むstatus | 未追跡を除外したstatus |
|---|---:|---:|
| cacheなし | 469.903 / 476.285 | 132.780 / 133.900 |
| FSMonitorのみ | 365.449 / 369.763 | 28.442 / 28.831 |
| FSMonitor + untracked cache | 42.545 / 43.022 | 29.160 / 29.487 |

FSMonitorとuntracked cacheを併用したShsh全体は次の結果になった。

| 状態 | 初期表示 | branch表示 | Git状態完了 | worker内Git計算 |
|---|---:|---:|---:|---:|
| Clean | 2.198 / 2.392 | 14.045 / 15.363 | 50.454 / 63.291 | 47.148 / 59.929 |
| Dirty | 2.192 / 2.528 | 13.797 / 14.882 | 54.379 / 55.753 | 51.094 / 52.437 |

cacheがwarmなローカルfilesystemでは、標準Gitでも詳細statusを約50 msで表示できる。最初のindex走査やnetwork filesystemでは同じ性能を期待できない。

## 個別処理の測定

porcelain解析を変更するときは、PTY測定の前に関数単体を比較する。

```sh
zsh tests/prompt/benchmark_status.zsh <baseline-ref> <サンプル数> <record数>
```

自動fetchはnetwork latencyを含めず、決定的なworker関数で頻度制限とworker分離を確認する。同じリポジトリで5分以内に1回だけqueueされ、ローカルrefreshではcancelされず、foreground fetchだけがnetwork workerをcancelすることを条件とする。
