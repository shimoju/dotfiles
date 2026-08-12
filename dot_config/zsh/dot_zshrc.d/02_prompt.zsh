# Pure
autoload -Uz promptinit
promptinit

zstyle ':prompt:pure:environment:virtualenv' show no
zstyle ':prompt:pure:environment:nix-shell' show no
zstyle ':prompt:pure:git:dirty' detailed yes
zstyle ':prompt:pure:git:stash' show yes

prompt pure
