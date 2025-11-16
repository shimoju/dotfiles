scriptencoding utf-8

" シンタックスハイライト
syntax enable

" 行番号を表示
set number
" カーソルが何行目の何列目に置かれているかを表示
set ruler
" 対応する括弧を強調
set showmatch

" インクリメンタルサーチを使用
set incsearch
" 検索結果を強調表示
set hlsearch
" 大文字/小文字の区別なく検索
set ignorecase
" 検索文字列に大文字が含まれている場合は区別して検索
set smartcase

" 改行時に前の行のインデントを継続する
set autoindent
" 改行時に入力された行の末尾に合わせて次の行のインデントを増減する
set smartindent
" タブの代わりにスペースを入力する
set expandtab
" 行頭の余白内でタブを打つとshiftwidthの数だけインデントする
set smarttab
" タブ文字の表示幅
set tabstop=2
" 自動インデントで挿入されるインデントの幅
set shiftwidth=2
" 連続した空白に対してタブキーやバックスペースキーでカーソルが動く幅
set softtabstop=2

" 変更中のファイルでも、保存しないで他のファイルを表示する
set hidden

" バックアップファイル(~)を作成しない
set nobackup
" アンドゥファイル(.un~)を作成しない
set noundofile
