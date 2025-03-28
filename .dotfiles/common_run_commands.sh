# .zshrc: Run at start of every interactive shell
# Typically used for shell setup, aliases, functions, prompts, key bindings etc

# ----------------------------------------
# Common aliases
# ----------------------------------------

alias ls="ls -a --color=auto"
alias ll="ls -alD %Y-%m-%d"
alias lw="ls -lD %Y-%d-%m --color=auto ~/monos"
alias git-prune="git branch --v | grep '\[gone\]' | awk '{print \$1}' | xargs git branch -D"
# alias py="$(brew --prefix)/opt/python@3.10/bin/python3.10"

# ----------------------------------------
# Prompt and color settings
# ----------------------------------------

CLICOLOR=1
export LSCOLORS=Exfxcxdxbxegedabagacad # see 'man zsh' for LSCOLORS`

# Set up prompt with git integration if available
if [ -f ~/.git-prompt.sh ]; then
    source ~/.git-prompt.sh

    function git_prompt() {
        __git_ps1 '%s ' | sed 's/.*\///'
    }

    setopt PROMPT_SUBST ; PS1='%F{green}ts %B%F{cyan}%~ %b%F{yellow}$(git_prompt)%B%F{141}%# %f%b'
else
    # Fallback to old prompt if git-prompt.sh is not available
    PS1='%F{green}ts %B%F{cyan}%~ %F{141}%# %f%b'
fi

# Zsh auto completion
autoload -Uz compinit && compinit

# ----------------------------------------
# Dotfiles
# ----------------------------------------

alias dotfiles='git --git-dir=$HOME/.dotfiles/.git --work-tree=$HOME'

# ----------------------------------------
# 3rd party add-ons
# ----------------------------------------

# Fuzzy finder (fzf)
if which fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
else
    echo "fzf not found.\nCan install with\n\tbrew install fzf"
fi

# Syntax highlighting
if [ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
else
    echo "zsh-syntax-highlighting not found.\nCan install with\n\tbrew install zsh-syntax-highlighting"
fi
