#!/bin/zsh

# Install missing tools listed in shell-tools/tools.sh, set up git identity,
# and set up app settings (VSCode/Cursor symlinks, iTerm2 prefs folder). Safe to re-run: anything already done is skipped.
# Usage: source ~/.dotfiles/install_tools.sh

DOTFILES_DIR="$HOME/.dotfiles"
source "$DOTFILES_DIR/shell-tools/tools.sh"

_installed=0 _present=0 _failed=()

# ----------------------------------------
# Tools (list lives in shell-tools/tools.sh)
# ----------------------------------------

_have_brew=1
if ! command -v brew >/dev/null 2>&1; then
    _have_brew=0
    echo "⚠️  Homebrew not found. Install it first, then re-run this script:"
    echo '   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
fi

for tool in "${DOTFILES_TOOLS[@]}"; do
    if dotfiles_tool_installed "$tool"; then
        echo "✅ $tool already installed"
        _present=$((_present + 1))
    elif dotfiles_tool_needs_brew "$tool" && [ "$_have_brew" = 0 ]; then
        echo "⏭️  $tool skipped (needs Homebrew)"
        _failed+=("$tool")
    else
        echo "Installing $tool..."
        if dotfiles_tool_install "$tool"; then
            echo "✅ $tool installed"
            _installed=$((_installed + 1))
        else
            echo "❌ $tool failed to install"
            _failed+=("$tool")
        fi
    fi
done

# ----------------------------------------
# Git identity (fetched from GitHub; never overwrites existing config)
# ----------------------------------------

if [ -n "$(git config --global user.name)" ] && [ -n "$(git config --global user.email)" ]; then
    echo "✅ git identity already set ($(git config --global user.name) <$(git config --global user.email)>)"
else
    # GitHub username comes from this repo's own remote, e.g. git@github.com:<user>/dotfiles.git
    _remote="$(git -C "$DOTFILES_DIR" remote get-url origin 2>/dev/null)"
    _gh_user="${${_remote#*github.com[:/]}%%/*}"
    _gh_json="$(curl -fsSL "https://api.github.com/users/$_gh_user" 2>/dev/null)"
    _gh_id="$(echo "$_gh_json" | plutil -extract id raw -o - - 2>/dev/null)"
    _gh_name="$(echo "$_gh_json" | plutil -extract name raw -o - - 2>/dev/null)"
    if [ -n "$_gh_user" ] && [ -n "$_gh_id" ]; then
        [ -z "$(git config --global user.name)" ] && git config --global user.name "${_gh_name:-$_gh_user}"
        # GitHub's no-reply address keeps your real email private and passes email-privacy push checks
        [ -z "$(git config --global user.email)" ] && git config --global user.email "${_gh_id}+${_gh_user}@users.noreply.github.com"
        echo "✅ git identity set from GitHub ($(git config --global user.name) <$(git config --global user.email)>)"
        _installed=$((_installed + 1))
    else
        echo "❌ Couldn't fetch git identity from GitHub. Set it manually:"
        echo '   git config --global user.name "Your Name"; git config --global user.email "you@example.com"'
        _failed+=("git identity")
    fi
    unset _remote _gh_user _gh_json _gh_id _gh_name
fi

# ----------------------------------------
# iTerm2 settings (iTerm2 loads its prefs from apps/iterm2/)
# ----------------------------------------

if [ -d "/Applications/iTerm.app" ]; then
    _iterm_dir="$DOTFILES_DIR/apps/iterm2"
    if [ "$(defaults read com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null)" = "$_iterm_dir" ] \
       && [ "$(defaults read com.googlecode.iterm2 LoadPrefsFromCustomFolder 2>/dev/null)" = "1" ]; then
        echo "✅ iTerm2 already loads settings from dotfiles"
        _present=$((_present + 1))
    else
        defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$_iterm_dir"
        defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
        echo "✅ iTerm2 set to load settings from dotfiles (takes effect next time iTerm2 starts)"
        _installed=$((_installed + 1))
    fi
    unset _iterm_dir
fi

# ----------------------------------------
# VSCode / Cursor settings (symlinked to dotfiles)
# ----------------------------------------

for editor in "Code" "Cursor"; do
    user_dir="$HOME/Library/Application Support/$editor/User"
    [ -d "$user_dir" ] || continue
    for f in settings.json keybindings.json; do
        src="$DOTFILES_DIR/apps/vscode/$f"
        dest="$user_dir/$f"
        if [ "$(readlink "$dest")" = "$src" ]; then
            echo "✅ $editor $f already linked"
            _present=$((_present + 1))
        else
            ln -sf "$src" "$dest"
            echo "✅ $editor $f linked to dotfiles"
            _installed=$((_installed + 1))
        fi
    done
done

# ----------------------------------------
# Summary
# ----------------------------------------

echo ""
if [ ${#_failed[@]} -eq 0 ]; then
    if [ "$_installed" -eq 0 ]; then
        echo "✨ Everything was already set up. Nothing to do."
    else
        echo "✨ Set up $_installed item(s), $_present already done. Open a new terminal to apply changes."
    fi
else
    echo "⚠️  Set up $_installed item(s), $_present already done, ${#_failed[@]} not done: ${_failed[*]}"
fi
unset _installed _present _failed _have_brew tool editor user_dir f src dest
