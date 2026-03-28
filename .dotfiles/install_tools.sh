#!/bin/zsh

# Install missing tools referenced in common_run_commands.sh
# Usage: source ~/.dotfiles/install_tools.sh

# ----------------------------------------
# .git-prompt.sh
# ----------------------------------------

if [ ! -f "$HOME/.git-prompt.sh" ]; then
    echo "Installing .git-prompt.sh..."
    curl -fsSL "https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh" -o "$HOME/.git-prompt.sh"
    echo "✅ .git-prompt.sh installed"
else
    echo "✅ .git-prompt.sh already installed"
fi

# ----------------------------------------
# fzf
# ----------------------------------------

if ! which fzf >/dev/null 2>&1; then
    echo "Installing fzf..."
    brew install fzf
    echo "✅ fzf installed"
else
    echo "✅ fzf already installed"
fi

# ----------------------------------------
# zsh-syntax-highlighting
# ----------------------------------------

zsh_high_path="$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
if [ ! -f "$zsh_high_path" ]; then
    echo "Installing zsh-syntax-highlighting..."
    brew install zsh-syntax-highlighting
    echo "✅ zsh-syntax-highlighting installed"
else
    echo "✅ zsh-syntax-highlighting already installed"
fi

# ----------------------------------------
# AltTab
# ----------------------------------------

if [ ! -d "/Applications/AltTab.app" ]; then
    echo "Installing AltTab..."
    brew install --cask alt-tab
    echo "✅ AltTab installed"
else
    echo "✅ AltTab already installed"
fi

echo ""
echo "✨ All tools installed! Open a new terminal to apply changes."
