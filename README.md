# dotfiles

## Install

```sh
$ xcode-select --install
$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
$ brew install chezmoi
$ chezmoi init https://github.com/shimoju/dotfiles.git
```

## Update

```sh
$ chezmoi update
```

Or

```sh
$ cd ~/.local/share/chezmoi
$ git pull
$ chezmoi apply
```
