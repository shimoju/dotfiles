# docker
alias dk='docker'
alias dkr='docker run --rm -it'
# dcは逆ポーランド記法の計算機コマンドで存在する
alias dc='docker compose'
alias dcu='docker compose up -d --remove-orphans'
alias dce='docker compose exec'
alias dcr='docker compose run --rm'
alias dcl='docker compose logs -f --tail=100'

# colima
if (( $+commands[colima] )); then
  export DOCKER_HOST="unix://$HOME/.colima/docker.sock"
fi

# kubectl
alias k='kubectl'
