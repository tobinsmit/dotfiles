
# ----------------------------------------
# Prompt and color settings
# ----------------------------------------

alias ls='ls --color=auto'
PROMPT='%F{green}%n %B%F{cyan}%~ %F{141}%# %f%b'
export LSCOLORS=Exfxcxdxbxegedabagacad # see 'man zsh' for LSCOLORS`

# ----------------------------------------
# Dotfiles alias
# ----------------------------------------

alias dotfiles='git --git-dir=$HOME/.dotfiles/.git --work-tree=$HOME'
