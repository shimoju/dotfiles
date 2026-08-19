# Pureの機能一覧と自作プロンプトへの採用判断

## 前提

対象は[Pure 1.28.3](https://github.com/sindresorhus/pure/tree/v1.28.3)。判断は次のプロンプトを目標にしている。

```text
user@host ~/src main*+? rebase ⇣⇡ ≡  ⎈ context/namespace      5s 16:23:42
❯
```

- 1行目: 状態表示。右側に実行時間と時刻
- 2行目: 入力用の`❯`だけ
- GitやKubernetesが遅くても入力を待たせない
- Powerline風の背景色やセパレータは使わない

採用欄の意味:

- `[x]`: 自作版へ採用
- `[ ]`: 初期実装では採用しない

## 表示とレイアウト

| 採用 | Pureの機能 | Pureでの状態 | 自作版での方針 |
|---|---|---|---|
| [x] | 2行プロンプト | 標準 | 1行目を状態、2行目を入力専用にする |
| [x] | カレントディレクトリ | 標準、`~`短縮付き | 同等。必要なら長いパスだけ省略する |
| [x] | パス区切りのdim表示 | opt-in | 見やすさが必要なら色設定として持つ |
| [x] | ミニマルな表示 | 標準 | 背景色やPowerlineセパレータを使わない |
| [x] | 成功・失敗の区別 | `❯`の色を変更 | 色で区別し、終了コードは常時表示しない |
| [x] | コマンド実行時間 | 既定で5秒超を表示 | 閾値を設定可能にし、1行目右側へ置く |
| [x] | SSH時の`user@host` | SSH時だけ表示 | 同等 |
| [x] | コンテナ時の`user@host` | Docker、Podman、LXC、OCI、nspawn、Kubernetesなど | 同等。検出は起動時にキャッシュする |
| [x] | root表示 | root時に`user@host`を別色で表示 | 同等 |
| [x] | サスペンド中ジョブ | `✦`を条件付き表示 | 条件付きなのでミニマルさを損なわない |
| [ ] | vi-mode記号 | Normal modeで`❮` | 現在はEmacs keymapなので不要 |
| [x] | 継続プロンプト | `…`とパーサー状態 | Zsh標準の状態を簡潔に表示する |
| [x] | デバッグプロンプト`PS4` | ファイル、関数、行番号、深さを表示 | シェルスクリプトのデバッグを損なわない形で採用 |
| [x] | ターミナルタイトル | 待機中はパス、実行中はコマンド | プロンプトを増やさず有用なので採用 |
| [x] | 色と記号の変更 | named、256色、RGBと記号の設定 | 少数の明示的な設定に限定する |
| [ ] | 全要素プレビュー | `prompt_pure_preview` | 初期実装では専用機能を作らない |

Pureの2行目には、virtualenv、Conda、Nix shell名が`❯`の前へ入る場合がある。現在の設定ではすべて非表示にしており、自作版でも2行目へ別要素を置かない。

## Git表示

| 採用 | Pureの機能 | Pureでの状態 | 自作版での方針 |
|---|---|---|---|
| [x] | ブランチ名 | 非同期 | 最初に返すGit情報として優先する |
| [x] | detached HEAD | 対応 | 短いcommit hashを表示する |
| [x] | dirty表示 | 標準は`*` | 採用 |
| [x] | 詳細dirty | 未ステージ`*`、ステージ済み`+`、未追跡`?` | 現在も有効。1回のstatus結果から分類する |
| [x] | Git操作中の状態 | rebase、merge、cherry-pickなど | 条件付き表示なので採用 |
| [x] | ahead／behind | `⇡`／`⇣` | 非同期で採用 |
| [x] | stash | stashがあれば`≡` | 現在も有効。非同期で採用 |
| [x] | 自動fetch | 既定で有効 | 入力を待たせず、失敗を静かに扱う条件で採用 |
| [x] | upstreamだけfetch | opt-in | リポジトリごとの調整項目として持つ |
| [x] | Git表示全体の無効化 | `zstyle`で設定可能 | リポジトリや環境単位のescape hatchとして採用 |
| [x] | 未追跡ファイルの除外 | 設定可能 | 巨大リポジトリ用のescape hatchとして採用 |
| [x] | 遅いdirty checkの抑制 | 5秒超なら既定30分キャッシュ | 採用。staleであることを見た目でも示す |
| [x] | index更新の抑制 | dirty checkで`GIT_OPTIONAL_LOCKS=0` | プロンプトをGit状態の副作用源にしない |
| [x] | Git処理の非同期化 | `zsh-async` worker | 自作版の中心要件 |
| [x] | 段階的な表示 | branch、dirtyなどを別callbackで反映 | Pureと同等の体感速度に必要 |
| [x] | 古い結果の破棄 | generationとPWDを照合 | `cd`競合を防ぐため必須 |
| [x] | 実行中処理のcancel | 作業ツリー変更時にflush | 必須 |
| [x] | 同名jobの重複防止 | unique job | Enter連打時の負荷を抑えるため採用 |
| [x] | foreground Gitとの競合回避 | pull／fetch実行時にbackground fetchをcancel | lock・通信競合を避けるため採用 |
| [x] | 認証promptの抑止 | fetchでterminal prompt、SSH password、GPG TTYを無効化 | background jobから端末を壊さないため必須 |
| [x] | worker障害時の縮退 | 再起動し、失敗時はGit表示を消す | プロンプト入力を最優先する |
| [x] | workerの低優先度化 | `renice`、利用可能なら`ionice` | UIやビルドへのI/O影響を抑える |

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
| [x] | カスタムprefix／suffix | `prompt_pure_precustom` | 拡張点は持つが、低コストなデータ参照だけ許す |
| [x] | 現在時刻 | 組み込みなし。custom suffixで追加可能 | 1行目右端へ`HH:MM:SS`で表示する |
| [x] | Kubernetes context／namespace | 組み込みなし | 非同期またはキャッシュ付きで表示する |
| [ ] | 汎用言語バージョン | 組み込みなし | 必要になった言語だけ後から追加する |

PureのNode.js表示はディレクトリと`PATH`をキーにキャッシュするが、キャッシュmiss時の`node --version`はメインシェル側で同期実行される。自作版で言語バージョンを追加する場合は、workerで取得し、プロジェクト検出時だけ実行する。

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

## 実装フェーズ

### Phase 1: Pureと同じ体感速度

- 2行レイアウト
- ディレクトリ
- 成功・失敗
- 実行時間と現在時刻
- SSH／コンテナ／root
- 非同期Git branch
- 非同期の詳細dirty
- Git action、ahead／behind、stash
- generation、cancel、worker障害時の縮退
- 2行目を`❯`だけに固定

### Phase 2: 外部状態

- 自動fetch
- Kubernetes context／namespace
- slow dirty cacheとstale表示
- workerの優先度調整
- 狭い端末での省略規則

### Phase 3: 必要性が確認できたものだけ

- 言語バージョン
- upstream限定fetchのUI設定
- Gitの件数表示
- プレビュー／デバッグ表示

## 採用判断の要約

自作版で再現したいPureの本質は、見た目よりも次の処理モデルにある。

1. 同期部分だけで入力プロンプトを即座に返す。
2. ブランチを早い段階で追加する。
3. dirty、ahead／behind、stash、fetchを入力から切り離す。
4. 非同期結果にgenerationとPWDを持たせ、古い結果を捨てる。
5. workerが失敗しても、Git情報がないだけの通常プロンプトへ縮退する。

2026-08-19の再測定では、LLVMでGit状態の完了に約492–496 msかかっても、Pureは中央値1 ms未満で入力可能になった。自作版の最優先KPIも、Git処理の絶対時間ではなく入力可能になるまでの時間とする。

GeometryとTypewrittenを含む機能・実装・実測の比較は[Pure・Geometry・Typewrittenの比較](prompt-comparison.md)を参照。比較から、自作版にはTypewrittenの早いbranch jobと詳細status、Geometryの要素配列とKubernetes表示も参考として取り入れる。ただし、非同期処理の世代管理、cancel、縮退動作はPure相当を維持する。
