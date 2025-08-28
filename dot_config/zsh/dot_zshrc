#
# Executes commands at the start of an interactive session.
#

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

#
# Source .zshrc.d
#

for file in "${ZDOTDIR:-$HOME}/.zshrc.d"/**/*.zsh; do
  source "$file"
done
