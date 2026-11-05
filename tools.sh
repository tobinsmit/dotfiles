# Single source of truth for the tools common_run_commands.sh expects.
# Sourced by common_run_commands.sh (to warn about missing tools) and by
# install_tools.sh (to install them). Add new tools here only.

DOTFILES_TOOLS=(git-prompt eza fzf zsh-syntax-highlighting alt-tab 1password-cli)

# Put Homebrew on PATH if it's installed but not yet on PATH (e.g. fresh Apple Silicon Mac)
if ! command -v brew >/dev/null 2>&1; then
    for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [ -x "$_brew" ] && eval "$("$_brew" shellenv)" && break
    done
    unset _brew
fi

dotfiles_zsh_highlight_path() {
    echo "${HOMEBREW_PREFIX:-$(brew --prefix 2>/dev/null)}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
}

# Exit status 0 if the tool is installed
dotfiles_tool_installed() {
    case "$1" in
        git-prompt)              [ -f "$HOME/.git-prompt.sh" ] ;;
        eza)                     command -v eza >/dev/null 2>&1 ;;
        fzf)                     command -v fzf >/dev/null 2>&1 ;;
        zsh-syntax-highlighting) [ -f "$(dotfiles_zsh_highlight_path)" ] ;;
        alt-tab)                 [ -d "/Applications/AltTab.app" ] ;;
        1password-cli)           command -v op >/dev/null 2>&1 ;;
        *)                       return 1 ;;
    esac
}

# Exit status 0 if the tool installs via Homebrew
dotfiles_tool_needs_brew() {
    [ "$1" != "git-prompt" ]
}

dotfiles_tool_install() {
    case "$1" in
        git-prompt) curl -fsSL "https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh" -o "$HOME/.git-prompt.sh" ;;
        alt-tab)    brew install --cask alt-tab ;;
        *)          brew install "$1" ;;
    esac
}
