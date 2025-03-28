CLICOLOR=1
alias ls='ls --color=auto'
PROMPT='%F{green}%n %B%F{cyan}%~ %F{141}%# %f%b'
export LSCOLORS=Exfxcxdxbxegedabagacad # see 'man zsh' for LSCOLORS
#export PATH="/usr/local/opt/python/libexec/bin:$PATH"
alias dotfiles='git --git-dir=$HOME/.dotfiles/.git --work-tree=$HOME'
