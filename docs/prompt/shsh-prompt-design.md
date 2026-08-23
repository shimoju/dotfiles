# Shshプロンプトの設計

## 目的

Shsh（shimoju's shell prompt）は、このリポジトリで使用するZshプロンプトである。Gitステータスの取得が重い環境でもシェルをすぐ入力可能にしつつ、日常の開発に必要な情報を、公開オプションや大規模なフレームワークなしで表示する。

想定する表示は次の形である。

```text
user@host ~/src main*+?# rebase-i ⇣⇡ ≡ ⎈ context/namespace      5s 16:23:42
❯
```

- 1行目にコンテキストとステータスを表示する。
- 2行目は入力記号だけにし、コマンドと出力をコピーしやすくする。
- GitとKubernetesは非同期で取得するため、入力記号の表示後に追加される場合がある。
- Powerlineセパレーター、言語バージョン、virtualenv、Nix、Nerd Fontsアイコンは表示しない。
- 表示や性能に関する公開オプションは設けない。標準状態を完成形として保つ。

`prompt shsh`を実行すると、Zshのprompt theme規約に従って、`fpath`から`prompt_shsh_setup`がautoloadされる。

## 関連ファイル

| ファイル | 役割 |
|---|---|
| [prompt_shsh_setup](../../dot_config/zsh/prompt/prompt_shsh_setup) | prompt本体 |
| [.zshrc](../../dot_config/zsh/dot_zshrc) | `fpath`、`promptinit`、`prompt shsh`の組み込み |
| [.zsh_plugins.txt](../../dot_config/zsh/dot_zsh_plugins.txt) | `zsh-async`の読み込み |
| [tests/prompt](../../tests/prompt) | 同期処理、非同期処理、外部連携、対話動作のtest |
| [prompt-benchmark.md](prompt-benchmark.md) | 性能測定の手順と現在の参考値 |

## 表示仕様

1行目の表示順は次のとおり。

1. サスペンド中ジョブの`✦`（該当時のみ）
2. root、SSH、コンテナでの`user@host`
3. カレントディレクトリ
4. Gitブランチまたはdetached HEADの短いcommit hash
5. Gitのworktree状態、実行中操作、upstreamとの差分、stash
6. Kubernetesのcontextとnamespace
7. 右寄せしたコマンド実行時間と現在時刻

入力記号は直前のコマンドが成功した場合はGreen、失敗した場合はRedにする。5秒を超えたコマンドは、短い形式で実行時間を表示する。時刻は`precmd`で確定し、非同期の再描画によってコマンド完了時刻がずれないようにする。

Gitマーカーは次の意味を持つ。

| マーカー | 意味 |
|---|---|
| `*` | unstagedの変更 |
| `+` | stagedの変更 |
| `?` | 未追跡ファイル |
| `#` | 未解決のconflict |
| `!` | Git statusを取得できず状態が不明 |
| `⇣` | upstreamよりbehind |
| `⇡` | upstreamよりahead |
| `≡` | 1件以上のstash |

Git操作中は`rebase-i`、`rebase-m`、`rebase`、`am`、`merge`、`cherry-pick`、`revert`、`bisect`のいずれかを表示する。conflictは通常の作業を止める状態なのでRed、通常のdirty状態はPeachとして区別する。status出力は全体を一度取得し、porcelain v2のrecord種別を先頭文字で判定する。pipeから1行ずつ読む処理と不要な文字列分割を避けることで、大量dirty時の解析costを抑える。status取得に失敗した場合は途中まで解析した結果を破棄し、dirtyかcleanかを断定せずYellowの`!`を表示する。

Kubernetesは`⎈ context/namespace`と表示する。Gitにはアイコンを付けず、KubernetesだけにUnicode記号を残すことで、表示頻度の高いGitプロンプトをミニマルに保つ。選択中のcontextにnamespaceがなければ`default`を表示する。

## 同期処理

入力を返すまでの同期処理では、`git`や`kubectl`などの外部コマンドを実行しない。次の処理だけをZsh内部で行う。

- 直前の終了ステータスの保存と実行時間の計算
- ターミナルタイトルの更新
- キャッシュ済みのGit・Kubernetes表示値の参照
- パスの短縮とレイアウト計算
- プロンプトの描画
- 非同期jobの投入。初回は`zsh-async`のZsh workerも初期化する

リポジトリの走査に数百msかかる場合でも、その処理を入力待ち時間に含めないことを、Git処理自体の絶対時間より優先する。

`PROMPT`には固定した`$(_shsh_expand_prompt)`だけを設定する。prompt substitutionによって、Zshが再描画するたびに現在の状態と端末幅でレンダリングする。リポジトリ由来の文字列は生の`PROMPT`へ埋め込まず、レンダラーがデータとして出力する。さらに`%`をエスケープすることで、シェル構文に見えるブランチ名やパスが再評価されることを防ぐ。

## レイアウトとリサイズ

`RPROMPT`は2行目の入力行に配置されるため使用しない。代わりに、1行目の左側と右側の間へリテラルの空白を挿入して右寄せする。

レンダラーは現在の`COLUMNS`と、Zshの`${(m)#text}`による表示カラム幅を使用する。この幅はsystem `wcwidth`に基づくため、コードポイント数よりもCJKパスや結合文字を正確に扱える。East Asian Ambiguous文字を常に2カラムとする端末独自設定はsystem幅と食い違う可能性があるが、その設定をシェルから移植可能な方法で取得することはできない。

幅が足りない場合は次の順で調整する。

1. ディレクトリ境界を保ってパスを短縮する。
2. 実行時間を残して時刻を省略する。
3. それでも収まらなければ右側全体を省略する。
4. 最後のパス要素自体が長い場合は、左側を省略して末尾を残す。

最後の処理では二分探索で収まるsuffixを求める。表示幅指定substring flag `(ml:)`は、長いマルチバイト文字列を処理するとクラッシュするため使用しない。この問題はmacOS付属のApple Zsh 5.9とHomebrew Zsh 5.9.2の両方で再現を確認している。

独自の`TRAPWINCH`は設けない。Zsh標準のリサイズ処理が固定した`PROMPT`を再展開し、レンダラーが最初の再描画から新しい幅を参照する。追加trapによる二度目の描画は、端末を連続して縮小したときに旧幅のプロンプトを階段状に残す原因になった。リサイズで更新するのは入力中のプロンプトだけであり、すでにスクロールバックへ入ったプロンプトは書き換えない。

## Gitの非同期処理

Shshは`zsh-async`を直接使用し、branch、status、upstream、alias、自動fetchをそれぞれの性質に合わせて実行する。

ローカル処理用の`_shsh` workerには次を投入する。

- branch、リポジトリroot、実行中のGit操作
- `git status --porcelain=v2 --show-stash --untracked-files=normal --no-renames`による詳細status
- branch確定後の`git rev-list`によるahead／behind
- 展開結果に`pull`または`fetch`を含むGit aliasの検出

branchとstatusを別jobにすることで、巨大なworktreeの走査完了を待たずにbranchを先行表示する。dirty、staged、untracked、conflict、stashは1回のstatus出力から判定する。statusでは`GIT_OPTIONAL_LOCKS=0`を設定し、プロンプトによるindex更新や任意lockとの競合を避ける。Gitが非zeroで終了した場合はjobの終了codeをcallbackへ伝え、部分的なstatusを表示へ反映しない。

ローカルjobの結果にはgenerationと作業ディレクトリを含める。callbackは現在のgenerationと`$PWD`に一致しない結果を破棄し、移動前または古いプロンプトの結果が現在の表示を上書きしないようにする。更新時は不要になったローカルjobをflushし、複数結果がまとまって届いた場合は再描画をまとめる。

worker停止時は古いGit表示を消して再起動を試みる。再起動できない場合も、Git表示がないだけのプロンプトとして入力を継続できる。unborn branchは`git symbolic-ref`、detached HEADは短いcommit hashへfallbackする。リポジトリ外へ移動した場合は、同じprompt更新中にGit表示を消す。

## 自動fetch

ネットワークfetchは専用の`_shsh_fetch` workerで実行する。ローカルGit workerの更新によって、通信中のfetchがcancelされないようにする。

同じshellではリポジトリごとに5分に1回までqueueへ投入する。成功時ではなく投入時に時刻を記録するため、remoteへ接続できない場合や認証に失敗する場合も、コマンドごとに再試行しない。

fetchは次の制約で実行する。

- `$HOME`自体がリポジトリrootの場合は実行しない。
- terminal、credential manager、SSH password、GPG TTYを使った対話を禁止する。
- 自動maintenanceとgarbage collectionを無効にする。
- tag、prune、submoduleを対象外にする。
- 失敗は表示せず、成功時はupstream矢印だけを更新する。

foregroundで`git pull`、`git fetch`、またはそのどちらかへ展開されるGit aliasを実行する前には、background fetchだけをcancelし、同じリポジトリの実行間隔を更新する。alias一覧は現在のリポジトリrootに紐付け、同じリポジトリ内のsubdirectoryでは再利用する。cacheと実行時刻はshell process内だけで保持し、リポジトリへmarker fileを書かず、複数shell間でも共有しない。

## Kubernetesの非同期処理

同期側のsignature確認にはZshのcommand tableと`zsh/stat`を使い、外部プロセスを起動しない。signatureには`KUBECONFIG`と、読み取り可能な設定ファイルの更新時刻・サイズを含める。signatureが変わった場合、ローカルworkerで次を実行する。

```sh
kubectl config view --minify \
  --output='jsonpath={.current-context}{"\t"}{.contexts[0].context.namespace}'
```

ローカルのkubeconfigだけを読み、cluster APIへは接続しない。`kubectl`が存在しない場合や設定を読めない場合は、同じprompt更新中に既存のKubernetes表示を消す。

## 外部プロセス

promptの描画とリサイズ処理は外部コマンドを実行しない。Shshが直接起動するprocessは次のとおり。

| プログラム | 用途 |
|---|---|
| `zsh` | `zsh-async`のローカル処理用workerとfetch用worker |
| `git` | branch、status、Git操作、upstreamとの差分、alias、自動fetch |
| `kubectl` | ローカルkubeconfigからcontextとnamespaceを取得 |

自動fetchの`git`は、remoteとGit設定に応じてtransportやcredential helperを起動する可能性がある。SSH transportにはbatch modeを付け、`GIT_ASKPASS=true`により認証promptを拒否する。`zsh-async`は常駐するZsh workerとZLEのfile descriptor callbackを使用する。このworker processは、リポジトリ処理とネットワーク処理を入力経路から外すための意図した依存である。

## Gitの高速化方針

Shshは常に未追跡ファイルを含め、slow dirty cacheを実装しない。古い表示や`?`の欠落よりも、非同期scanの時間が長い方を許容する。巨大なリポジトリではGit標準のcacheを使用する。

```sh
git config --local core.fsmonitor true
git config --local core.untrackedCache true
```

FSMonitorは追跡済みファイルの確認を減らし、untracked cacheは変更のないディレクトリの再走査を避ける。通常の`git status`がそのまま恩恵を受けるため、Shsh側にcache invalidationを実装する必要がない。対応するfilesystem上の大規模リポジトリ単位で有効にし、数回の`git status`でcacheをwarm upする。

LLVMでの参考測定では、両方を無効にした475.0 msから、両方を有効にした44.8 msまで短縮した。条件と未追跡除外との比較は[ベンチマーク手順](prompt-benchmark.md#gitキャッシュの参考値)を参照。

## 配色

色はすべてCatppuccin Mochaのpaletteから選び、内部連想配列`_shsh_colors`に集約する。

| 役割 | 色 |
|---|---|
| 成功 | Green `#a6e3a1` |
| 失敗、root、conflict | Red `#f38ba8` |
| 実行時間、サスペンド中ジョブ、Git status不明 | Yellow `#f9e2af` |
| パス | Blue `#89b4fa` |
| branch | Mauve `#cba6f7` |
| dirty | Peach `#fab387` |
| Git操作 | Pink `#f5c2e7` |
| ahead／behind | Teal `#94e2d5` |
| stash | Rosewater `#f5e0dc` |
| Kubernetes | Sapphire `#74c7ec` |
| identity | Lavender `#b4befe` |
| 時刻と区切り | Overlay 1 `#7f849c` |

識別子、変化、実行状態、環境を役割ごとにまとめる。branchをGreenにしないことで、コマンド成功の意味と衝突させない。

## 保守時の原則

変更時は次の条件を維持する。

1. 同期描画経路で外部プロセスを起動しない。
2. 2行目には入力記号以外を追加しない。
3. 非同期結果をgenerationと作業ディレクトリで検証する。
4. ネットワーク処理をローカルGit処理から分離し、リポジトリごとに頻度制限する。
5. 画面に出すGit statusは1回の詳細statusから取得する。
6. 幅は文字数ではなく表示カラム数で計算する。
7. worker障害やtool不足は、入力停止ではなく表示要素の省略へ縮退させる。
8. 新機能は公開オプションなしでも有用な場合だけ追加する。

実装修正後はprompt用test suiteを実行する。

```sh
export ASYNC_ZSH_PATH=/path/to/zsh-async/async.zsh

zsh tests/prompt/test_sync.zsh
zsh tests/prompt/test_git.zsh
zsh tests/prompt/test_async.zsh
zsh tests/prompt/test_external.zsh
zsh tests/prompt/test_entrypoint.zsh
zsh tests/prompt/test_interactive.zsh
```

`ASYNC_ZSH_PATH`には実際にinstallされている`zsh-async/async.zsh`を指定する。各testは順に、Zsh内部の描画、Git出力の解析、実workerと古い結果の破棄、fetch・Kubernetes連携、起動時の組み込み、ZLE bufferの保持と連続resizeを確認する。性能に影響する変更では[ベンチマーク手順](prompt-benchmark.md)も実行する。
