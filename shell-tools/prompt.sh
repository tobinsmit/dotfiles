# Prompt, completion, 3rd-party shell add-ons, and missing-tools warning. Sourced by common_run_commands.sh

# ----------------------------------------
# Prompt and color settings
# ----------------------------------------

CLICOLOR=1
export LSCOLORS=Exfxcxdxbxegedabagacad # see 'man zsh' for LSCOLORS`

if [ -f "$HOME/.git-prompt.sh" ]; then
    source "$HOME/.git-prompt.sh"

    function git_prompt() {
        __git_ps1 '%s ' | sed 's/.*\///'
    }

    setopt PROMPT_SUBST ; PS1='%F{green}${PROMPT_LABEL:-ts} %B%F{cyan}%~ %b%F{yellow}$(git_prompt)%B%F{141}%# %f%b'
else
    # Fallback to old prompt if git-prompt.sh is not available
    setopt PROMPT_SUBST ; PS1='%F{green}${PROMPT_LABEL:-ts} %B%F{cyan}%~ %F{141}%# %f%b'
fi

# ----------------------------------------
# 3rd party add-ons
# ----------------------------------------

# Zsh auto completion
autoload -Uz compinit && compinit

# Fuzzy finder (fzf)
if dotfiles_tool_installed fzf; then
    source <(fzf --zsh)
fi

# Syntax highlighting
if dotfiles_tool_installed zsh-syntax-highlighting; then
    source "$(dotfiles_zsh_highlight_path)"
fi

# Warn about any tools from tools.sh that aren't installed
MISSING_TOOLS=()
for tool in "${DOTFILES_TOOLS[@]}"; do
    dotfiles_tool_installed "$tool" || MISSING_TOOLS+=("$tool")
done
unset tool
if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo "\n🥵 Missing tools: ${MISSING_TOOLS[*]}"
    echo "✨ To install missing tools, run:"
    echo "  source ~/.dotfiles/install_tools.sh\n"
fi

