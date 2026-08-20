# Pure・Geometry・Typewrittenの比較

## 結論

現在の要件ではPureを第一候補とする。LLVM規模のリポジトリでも入力可能になるまでの時間が最短で、非同期結果の競合対策、自動fetch、コマンド実行時間、SSH／コンテナ表示まで揃っている。

次点はTypewrittenを`TYPEWRITTEN_PROMPT_LAYOUT=pure`で使う構成。ブランチ表示は3候補で最速であり、Pure風レイアウトにも性能上のペナルティは見られなかった。ただし、初期表示の同期処理、Git状態完了の遅さ、自動fetchやコマンド実行時間がない点ではPureに劣る。

Geometryは構成要素の組み替えやKubernetes・言語表示が最も充実するが、今回の巨大リポジトリではGitを一括表示するまでの待ち時間が長く、Git表示を重視する用途の第一候補にはしない。

実測値と再測定手順は[Zshプロンプトのベンチマーク](prompt-benchmark.md)、Pureの詳細な採用判断は[Pureの機能一覧と自作プロンプトへの採用判断](pure-feature-evaluation.md)を参照。

## 比較対象

| プロンプト | 対象revision | 備考 |
|---|---|---|
| [Pure](https://github.com/sindresorhus/pure/tree/v1.28.3) | 1.28.3、`89c9e30` | 2026-07-16 |
| [Geometry](https://github.com/geometry-zsh/geometry/tree/0f82c567db277024f340b5854a646094d194a31f) | `0f82c56` | 2025-01-13 |
| [Typewritten](https://github.com/reobin/typewritten/tree/06f8575e24792b2a9cd9539e39b537801ec1b4c0) | 1.5.2、`06f8575` | 取得時のmain |

Typewrittenは取得したmainの先頭が2026-05-13だが、このcommitはドキュメント変更である。Git表示や描画方式を評価するときは、リポジトリの最終更新日だけでなく対象ソースの変更履歴も確認する。

## 要件との比較

記号の意味:

- `○`: 組み込みで対応
- `△`: 設定または自作拡張で対応できるが制約あり
- `—`: 組み込みなし

| 機能 | Pure | Geometry | Typewritten |
|---|---|---|---|
| ミニマル表示 | ○ | ○ | ○ |
| 2行レイアウト | ○ 標準 | △ `geometry_newline`で構成 | ○ `pure`など複数layout |
| ディレクトリ | ○ | ○ | ○、Git root相対にも対応 |
| 成功・失敗 | ○ 記号の色 | ○ status／exit code | ○ 記号の色、終了コードも可 |
| Git非同期表示 | ○ 複数job | ○ RPROMPTを一括 | ○ branchとstatusを分離 |
| 詳細dirty | ○ `*+?` | △ generic dirty、conflict数 | ○ `? + ! » — $ #` |
| ahead／behind | ○ 矢印 | ○ | ○ ahead／behind／diverged |
| stash | ○ opt-in | ○ | ○ 件数 |
| Git操作中状態 | ○ | △ rebase | △ detached HEADをrebase扱い |
| 自動fetch | ○ 既定有効 | — | — |
| コマンド実行時間 | ○ | — | — |
| 現在時刻 | △ custom hook | △ 構成要素を追加 | △ prefix function |
| SSH／container／root | ○ 条件付き | △ hostname等を構成 | △ verbose layoutのuser／host |
| Kubernetes | — | ○ | △ prefix functionの例あり |
| 言語・環境 | Node、Python、Conda、Nix | Node、npm、Ruby、Rust、virtualenv | — |
| Mercurial／Jujutsu | — | ○ | — |
| ターミナルタイトル | ○ | ○ | — |
| カーソル形状 | — | — | ○ |

Geometryの「実行時間」に見えるGit time要素は最終commitからの経過時間であり、直前コマンドの実行時間ではない。

## 非同期実装の違い

### Pure

- 対象実装: [`pure.zsh`](https://github.com/sindresorhus/pure/blob/89c9e30a38d3d35457bcc58b43ea6c28ae56934b/pure.zsh)
- 永続的な`zsh-async` workerへbranch、dirty、arrow、stash、fetchなどを別jobとして投入する。
- branchをdirtyより先に反映するため、完全なGit状態を待たずに有用な情報が見える。
- 世代番号と`PWD`をcallbackで照合し、`cd`前の古い結果を破棄する。
- 作業ツリー変更時のcancel、同名jobの重複防止、worker再起動と縮退動作を持つ。
- `GIT_OPTIONAL_LOCKS=0`を使い、workerを`renice`、利用可能なら`ionice`する。
- foregroundのpull／fetchとbackground fetchの競合や、background認証promptを避ける。

入力応答だけでなく、結果の鮮度と障害時の安全性まで含めて最も堅牢である。

### Geometry

- 対象実装: [`geometry.zsh`](https://github.com/geometry-zsh/geometry/blob/0f82c567db277024f340b5854a646094d194a31f/geometry.zsh)、[`functions/geometry_git`](https://github.com/geometry-zsh/geometry/blob/0f82c567db277024f340b5854a646094d194a31f/functions/geometry_git)
- precmdごとにprocess substitutionを1つ作り、`GEOMETRY_RPROMPT`の全要素を子プロセスで計算する。
- Gitだけでなく、右プロンプトに追加したKubernetesや言語要素もまとめて非同期化できる。
- 永続workerはなく、Git branchとdirtyも一括で返るため段階表示されない。
- 世代番号や`PWD`をcallbackで検証する仕組みは見当たらず、遅い旧ディレクトリの結果を捨てる設計はPureより弱い。
- Git判定は`git diff-index --quiet HEAD`の後、前段がcleanなら`git status --porcelain --ignore-submodules`も実行する。

構造は単純で拡張しやすいが、巨大リポジトリではGit情報を早いものから見せる方式ではない。

### Typewritten

- 対象実装: [`typewritten.zsh`](https://github.com/reobin/typewritten/blob/06f8575e24792b2a9cd9539e39b537801ec1b4c0/typewritten.zsh)、[`lib/git.zsh`](https://github.com/reobin/typewritten/blob/06f8575e24792b2a9cd9539e39b537801ec1b4c0/lib/git.zsh)
- レイアウト設定: [`TYPEWRITTEN_PROMPT_LAYOUT`](https://github.com/reobin/typewritten/blob/06f8575e24792b2a9cd9539e39b537801ec1b4c0/docs/prompt_customization.md#typewritten_prompt_layout)
- `zsh-async` workerへbranchとstatusを別jobとして投入し、branchを先に反映する。
- precmdのメインシェル側で`git config --get oh-my-zsh.hide-status`と`git rev-parse --show-toplevel`を実行する。この同期処理が初期表示時間へ加算される。
- status jobは`git status --porcelain -b`の結果を複数の`grep`で分類し、stashも`git stash list | wc -l`で数える。
- ディレクトリまたはGit rootの変更時にjobをflushするが、callback結果へ世代番号や`PWD`を持たせて検証しない。
- worker error時の再起動はある。
- 日時やKubernetesを追加できるprefix functionは同期実行され、非同期callbackによる再描画時にも評価される。

ブランチの速さと詳細なGit記号は魅力だが、同期処理と拡張関数のコストには注意が必要である。

## ベンチマーク要約

LLVMのshallow clone、clean／dirty各15回の中央値。単位はms。

| 実装・状態 | 入力可能 | branch表示 | Git状態完了 |
|---|---:|---:|---:|
| Pure clean | 0.927 | 71.583 | 495.530 |
| Pure dirty | 0.860 | 69.661 | 491.888 |
| Shsh clean | 1.089 | 18.707 | 486.956 |
| Shsh dirty | 1.039 | 18.444 | 489.621 |
| Geometry clean | 13.904 | 一括 | 829.090 |
| Geometry dirty | 13.612 | 一括 | 340.386 |
| Typewritten default clean | 16.708 | 27.842 | 545.852 |
| Typewritten default dirty | 16.226 | 27.096 | 544.338 |
| Typewritten `pure` clean | 16.644 | 27.891 | 544.943 |
| Typewritten `pure` dirty | 16.530 | 27.353 | 544.290 |

Geometryのdirty値がcleanより速いのは、追跡済み変更を`git diff-index`で発見して後段を短絡したためである。未追跡ファイルだけのdirtyでは同じ短絡が起こらないので、「dirtyなら常に速い」という結果ではない。

Typewrittenのdefaultと`pure`はほぼ同じ結果だった。Pure風の2行レイアウトを選ぶこと自体は性能上の懸念にならない。

ShshはPure相当の入力開始時間とGit状態完了時間を維持しながら、branch表示を約18–19 msまで短縮した。軽いbranch jobと重いstatus jobを分離し、同期側ではGitコマンドを実行しない設計が狙いどおり機能している。

## メリット・デメリット

### Pure

メリット:

- 入力可能になるまでが最短
- Gitを段階表示し、重いdirty判定を体感待ち時間から外す
- 古い結果の破棄、cancel、worker障害時の縮退が堅牢
- 自動fetch、コマンド実行時間、SSH／コンテナ表示が組み込み
- 現在の要件と設定がすでに固まっている

デメリット:

- Kubernetes表示は組み込みではない
- 現在時刻や右寄せレイアウトはcustom hookだけでは衝突処理まで解決しない
- 言語表示は限定的

### Geometry

メリット:

- prompt要素を配列で並べ替える構成が分かりやすい
- Kubernetes、言語、Mercurial、Jujutsuまで組み込み要素が多い
- 右プロンプト全体を非同期化できる
- generic dirtyでよければ追跡済み変更を早く短絡できる

デメリット:

- Git branchとstatusが一括表示で、clean時の完了が今回最も遅い
- 詳細dirty表示が弱い
- 古い非同期結果を捨てる仕組みがPureほど堅牢ではない
- コマンド実行時間と自動fetchがない

### Typewritten

メリット:

- branch表示が今回最速
- 詳細なGit状態記号とstash件数を表示できる
- Pure風を含む複数のレイアウトとGit root相対パスを選べる
- `TYPEWRITTEN_PROMPT_LAYOUT=pure`に性能上のペナルティが見られない
- 色、記号、カーソル形状を細かく変更できる

デメリット:

- Git判定の一部が同期実行され、入力可能になるまでPureより約16 ms遅い
- Git状態完了はPureより約10%遅く、p95の揺らぎも大きい
- 自動fetch、コマンド実行時間、native Kubernetes表示がない
- prefix functionは同期実行なので、重い外部コマンドを置くと体感速度が悪化する
- 世代番号と`PWD`による古いcallbackの検証がない

## Shshへ取り入れた設計

Pureを土台に、他2つの良い部分を限定的に取り入れた。

1. Pureからworker lifecycle、世代管理、cancel、縮退動作、自動fetchを採る。自動fetchはローカルGit jobと別workerに置き、shellごと・リポジトリごとに5分に1回までとする。
2. Typewrittenのようにbranchを独立した軽いjobで先行表示し、branch確定後にahead／behindの軽量job、最後に詳細dirtyを反映する。
3. 1行目の要素を状態ごとに組み立て、端末幅が足りない場合は右側の低優先度要素から省略する。
4. KubernetesはGeometryの表示責務を参考にし、ローカルkubeconfigの変更時だけ非同期取得する。
5. Geometryのclean時の二重走査と、Typewrittenの同期Git判定・多数の補助processは避ける。

workerの`renice`／`ionice`は採用しなかった。初期化用jobと次のprompt refreshによるcancelが競合し、workerが結果を返さないタイミング依存を実測で確認したためである。通常優先度でも処理は非同期で、入力開始時間は約1 msに収まっている。

採用順位は次の通り。

1. Pure
2. Typewritten + `TYPEWRITTEN_PROMPT_LAYOUT=pure`
3. Geometry
