# Pureの機能一覧とShshへの採用判断

## 前提

対象は[Pure 1.28.3](https://github.com/sindresorhus/pure/tree/v1.28.3)。自作プロンプト名はShsh（shimoju's shell prompt）とし、次の表示を標準状態の目標にしている。

```text
user@host ~/src main*+? rebase ⇣⇡ ≡  ⎈ context/namespace      5s 16:23:42
❯
```

- 1行目: 状態表示。右側に実行時間と時刻
- 2行目: 入力用の`❯`だけ
- GitやKubernetesが遅くても入力を待たせない
- Powerline風の背景色やセパレータは使わない
- 公開設定を設けず、標準状態を理想の表示とする

採用欄の意味:

- `[x]`: 自作版へ採用
- `[ ]`: 初期実装では採用しない

## 表示とレイアウト

| 採用 | Pureの機能 | Pureでの状態 | 自作版での方針 |
|---|---|---|---|
| [x] | 2行プロンプト | 標準 | 1行目を状態、2行目を入力専用にする |
| [x] | カレントディレクトリ | 標準、`~`短縮付き | `~`短縮を使い、端末幅が足りない場合だけ固定規則で省略する |
| [ ] | パス区切りのdim表示 | opt-in | 採用しない |
| [x] | ミニマルな表示 | 標準 | 背景色やPowerlineセパレータを使わない |
| [x] | 成功・失敗の区別 | `❯`の色を変更 | 色で区別し、終了コードは常時表示しない |
| [x] | コマンド実行時間 | 既定で5秒超を表示 | 5秒超を1行目右側へ表示する。閾値は固定 |
| [x] | SSH時の`user@host` | SSH時だけ表示 | 同等 |
| [x] | コンテナ時の`user@host` | Docker、Podman、LXC、OCI、nspawn、Kubernetesなど | 同等。検出は起動時にキャッシュする |
| [x] | root表示 | root時に`user@host`を別色で表示 | 同等 |
| [x] | サスペンド中ジョブ | `✦`を条件付き表示 | 条件付きなのでミニマルさを損なわない |
| [ ] | vi-mode記号 | Normal modeで`❮` | 現在はEmacs keymapなので不要 |
| [x] | 継続プロンプト | `…`とパーサー状態 | Zsh標準の状態を簡潔に表示する |
| [x] | デバッグプロンプト`PS4` | ファイル、関数、行番号、深さを表示 | シェルスクリプトのデバッグを損なわない形で採用 |
| [x] | ターミナルタイトル | 待機中はパス、実行中はコマンド | プロンプトを増やさず有用なので採用 |
| [ ] | 色と記号の変更 | named、256色、RGBと記号の設定 | 配色と記号を標準仕様として固定する |
| [ ] | 全要素プレビュー | `prompt_pure_preview` | 不要 |

Pureの2行目には、virtualenv、Conda、Nix shell名が`❯`の前へ入る場合がある。現在の設定ではすべて非表示にしており、自作版でも2行目へ別要素を置かない。

### Structured Mauve配色

Catppuccin Mochaのパレットだけを使い、配色は公開設定にせずShshの標準仕様として固定する。実装ではsemantic roleをキーにした内部連想配列`_shsh_colors`へ集約する。

| 役割群 | 要素 | 色 |
|---|---|---|
| 実行状態 | 成功、失敗／root、遅延／サスペンド | Green `#a6e3a1`、Red `#f38ba8`、Yellow `#f9e2af` |
| 場所・環境 | path、Kubernetes、SSH／host | Blue `#89b4fa`、Sapphire `#74c7ec`、Lavender `#b4befe` |
| Git識別子 | branch、Git action、stash | Mauve `#cba6f7`、Pink `#f5c2e7`、Rosewater `#f5e0dc` |
| Gitの変化 | dirty、ahead／behind | Peach `#fab387`、Teal `#94e2d5` |
| 補助情報 | 現在時刻、継続・デバッグプロンプトの区切り | Overlay 1 `#7f849c` |

成功をGreen、警告をYellow、失敗をRedへ限定し、branchをMauveへ分離する。dirtyもYellowではなくPeachにすることで、遅いコマンドとの役割衝突を避ける。

## Git表示

| 採用 | Pureの機能 | Pureでの状態 | 自作版での方針 |
|---|---|---|---|
| [x] | ブランチ名 | 非同期 | 最初に返すGit情報として優先する |
| [x] | detached HEAD | 対応 | 短いcommit hashを表示する |
| [x] | dirty表示 | 標準は`*` | 採用 |
| [x] | 詳細dirty | 未ステージ`*`、ステージ済み`+`、未追跡`?` | 現在も有効。1回のstatus結果から分類する |
| [x] | Git操作中の状態 | rebase、merge、cherry-pickなど | 条件付き表示なので採用 |
| [x] | ahead／behind | `⇡`／`⇣` | branch確定後に軽量な`rev-list` jobで先行表示し、fetch後も同じ計算を再利用する |
| [x] | stash | stashがあれば`≡` | 現在も有効。非同期で採用 |
| [x] | 自動fetch | 既定で有効 | 常時有効。入力を待たせず、tag、prune、submoduleを対象外にして失敗を静かに扱う |
| [ ] | upstreamだけfetch | opt-in | 専用設定を持たず、Git標準のfetch動作へ固定する |
| [ ] | Git表示全体の無効化 | `zstyle`で設定可能 | 専用設定を持たない。障害時は自動的にGit表示なしへ縮退する |
| [ ] | 未追跡ファイルの除外 | 設定可能 | 専用設定を持たず、常に未追跡ファイルを表示する |
| [ ] | 遅いdirty checkの抑制 | 5秒超なら既定30分キャッシュ | 表示をstaleにしないため採用しない |
| [x] | index更新の抑制 | dirty checkで`GIT_OPTIONAL_LOCKS=0` | プロンプトをGit状態の副作用源にしない |
| [x] | Git処理の非同期化 | `zsh-async` worker | 自作版の中心要件 |
| [x] | 段階的な表示 | branch、dirtyなどを別callbackで反映 | Pureと同等の体感速度に必要 |
| [x] | 古い結果の破棄 | generationとPWDを照合 | `cd`競合を防ぐため必須 |
| [x] | 実行中処理のcancel | 作業ツリー変更時にflush | 必須 |
| [x] | 同名jobの重複防止 | unique job | Enter連打時の負荷を抑えるため採用 |
| [x] | foreground Gitとの競合回避 | pull／fetch実行時にbackground fetchをcancel | lock・通信競合を避けるため採用 |
| [x] | 認証promptの抑止 | fetchでterminal prompt、SSH password、GPG TTYを無効化 | background jobから端末を壊さないため必須 |
| [x] | worker障害時の縮退 | 再起動し、失敗時はGit表示を消す | プロンプト入力を最優先する |
| [ ] | workerの低優先度化 | `renice`、利用可能なら`ionice` | 初期化用の非同期jobとcancelが競合するため採用しない。Git処理自体を入力経路から外すことを優先する |

### Git標準機能による高速化

自作版には公開設定を設けない。常に未追跡ファイルを含む完全なGit状態を取得し、巨大リポジトリの高速化はGit標準のFSMonitorとuntracked cacheへ委ねる。

```sh
git config --local core.fsmonitor true
git config --local core.untrackedCache true
```

[FSMonitor](https://git-scm.com/docs/git-fsmonitor--daemon)は変更された可能性がある追跡済みファイルだけをGitへ通知し、全追跡ファイルへの`lstat`を避ける。[untracked cache](https://git-scm.com/docs/git-status.html#_untracked_files_and_performance)はディレクトリごとの未追跡状態をindexへ保持し、FSMonitorと組み合わせると変更されたディレクトリだけを再走査できる。プロンプト側は通常の`git status`を使うだけで両機能の恩恵を受ける。

同じLLVM cloneでウォームアップ後に測定すると、両機能が無効な完全statusは平均475.0 ms、FSMonitorだけでは366.6 ms、FSMonitorとuntracked cacheの併用では44.8 msだった。併用時に未追跡ファイルを除外しても31.2 msで、差は約14 msに縮まる。情報を欠落させる専用設定を追加するより、Git側のcacheを利用して完全かつ最新の状態を表示する。

設定は巨大リポジトリ単位の`--local`を基本とする。cacheは数回の`git status`でウォームアップされる。FSMonitorが利用できない環境では従来どおり全走査になるが、プロンプト処理は非同期なので入力を待たせない。

### Pureが標準では表示しないGit情報

| 採用 | 候補 | 判断 |
|---|---|---|
| [ ] | 変更ファイル数 | 表示量と計算量が増えるため初期版では不要 |
| [ ] | ahead／behindの数値 | 矢印だけで十分。必要性が出たら追加 |
| [ ] | upstream名 | 通常操作では情報量が多い |
| [ ] | tag | 初期版では不要 |
| [ ] | 常時commit hash | detached HEADの場合だけ表示する |

## 環境・言語・外部ツール

| 採用 | Pureの機能 | Pureでの状態 | 自作版での方針 |
|---|---|---|---|
| [ ] | Python virtualenv／Conda | 標準有効、2行目に表示 | 現在は無効。初期版には入れない |
| [ ] | Nix shell名 | 標準有効、2行目に表示 | 現在は無効。初期版には入れない |
| [ ] | Node.js major | opt-in | 初期版には入れない |
| [ ] | カスタムprefix／suffix | `prompt_pure_precustom` | 拡張点を設けず、必要な要素を標準機能として実装する |
| [x] | 現在時刻 | 組み込みなし。custom suffixで追加可能 | 1行目右端へ固定形式`HH:MM:SS`で表示する |
| [x] | Kubernetes context／namespace | 組み込みなし | kubeconfigを検出した場合だけ、非同期またはキャッシュ付きで表示する |
| [ ] | 汎用言語バージョン | 組み込みなし | 不要 |

Kubernetes表示ではcluster APIへ問い合わせず、ローカルのkubeconfigからcontextとnamespaceだけを取得する。context変更を検出できる範囲でキャッシュし、プロンプト入力を待たせない。

## Pureのカスタマイズ上の制約

Pureのprepromptは左から順に描画され、`RPROMPT`を使用しない。setup時には既存の`RPROMPT`を空にする。そのため、Powerlevel10k Lean Styleのように1行目の実行時間と時刻を端末右端へ安全に配置する機能は標準ではない。

`prompt_pure_precustom`を使えば時刻そのものは追加できるが、次も自前で扱う必要がある。

- 端末幅に応じた右寄せ
- 左側セグメントとの衝突回避
- resize後の再描画
- 非同期Git callbackによる再描画
- ANSI escape sequenceの表示幅

自作版では、1行目左側と右側をレイアウトエンジンの責務として扱い、幅が足りない場合は右側の低優先度要素から省略する。

## 補助機能の説明

### サスペンド中ジョブ

`Ctrl-Z`などで停止したjobが現在のシェルに残っている場合、1行目へ`✦`を表示する。終了していないプロセスを忘れず、`jobs`、`fg`、`bg`で処理するための注意表示である。Zshの`jobstates`を参照するだけなので外部プロセスを起動せず、通常時の表示も増えない。

### 継続プロンプト

引用符、パイプ、`if`、`for`などが閉じておらず、Zshが入力の続きを待っているときに使われる`PROMPT2`である。Pureは`…`と`%_`のパーサー状態を表示し、何の続きを待っているかを示す。通常のコマンド入力では表示されず、外部プロセスも使わない。

### デバッグプロンプト`PS4`

`set -x`または`setopt XTRACE`で実行トレースを有効にしたとき、各トレース行の先頭へ付く表示である。Pureは呼び出し深度、ファイル名、関数名、行番号を表示し、入れ子になったシェル処理を追いやすくする。通常の対話利用には表示・速度とも影響しない。

### ターミナルタイトル

端末のタブまたはウィンドウタイトルへ、入力待ちでは現在のディレクトリ、コマンド実行中ではディレクトリとコマンドを表示する。プロンプトの表示幅を消費せず、タブを見分けやすくなる。一方、引数に秘密情報を含むコマンドもタイトルへ出る可能性があり、terminal multiplexer側で上書きされる場合もある。

### 遅いdirty checkの抑制とstale表示

Pureはdirty checkに5秒を超えたリポジトリを遅いと判定し、その結果を保持して、既定では30分間再実行しない。その間はGit branchを別の色にして、表示が最新でない可能性を示す。コマンド実行のたびに重い走査が繰り返されるのを防げる一方、最大30分は実際の変更が反映されない可能性があり、キャッシュ状態と期限の管理も必要になる。自作版ではGit標準のFSMonitorとuntracked cacheを利用し、常に最新状態を取得するため、この機能は採用しない。

## 実装フェーズ

### Phase 1: Pureと同じ体感速度

- 2行レイアウト
- ディレクトリ
- 成功・失敗
- 実行時間と現在時刻（右プロンプト）
- SSH／コンテナ／root
- 非同期Git branch
- 非同期の詳細dirty
- Git action、ahead／behind、stash
- generation、cancel、worker障害時の縮退
- 2行目を`❯`だけに固定

### Phase 2: 外部状態

- 自動fetch
- Kubernetes context／namespace
- 狭い端末での省略規則

### Phase 3: 必要性が確認できたものだけ

- Gitの件数表示

## 採用判断の要約

自作版で再現したいPureの本質は、見た目よりも次の処理モデルにある。

1. 同期部分だけで入力プロンプトを即座に返す。
2. ブランチを早い段階で追加する。
3. ahead／behindを軽量jobで先に返し、dirty、stash、fetchを入力から切り離す。
4. 非同期結果にgenerationとPWDを持たせ、古い結果を捨てる。
5. workerが失敗しても、Git情報がないだけの通常プロンプトへ縮退する。
6. 表示結果を独自にcacheせず、Git標準のFSMonitorとuntracked cacheを透過的に利用する。

2026-08-19の再測定では、LLVMでGit状態の完了に約492–496 msかかっても、Pureは中央値1 ms未満で入力可能になった。実装したShshもGit状態の完了が約487–490 msである一方、入力可能になるまでの中央値を約1 msに維持した。最優先KPIはGit処理の絶対時間ではなく、入力可能になるまでの時間である。

GeometryとTypewrittenを含む機能・実装・実測の比較は[Pure・Geometry・Typewrittenの比較](prompt-comparison.md)を参照。比較から、自作版にはTypewrittenの早いbranch jobと詳細status、Geometryの要素配列とKubernetes表示も参考として取り入れる。ただし、非同期処理の世代管理、cancel、縮退動作はPure相当を維持する。
