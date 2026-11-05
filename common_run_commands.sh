# .zshrc: Run at start of every interactive shell
# Entry point sourced from ~/.zshrc. Keeps this filename so existing machines need no change.
# The actual config lives in shell-tools/ (one file per topic).

export HISTSIZE=100000
export SAVEHIST=100000

unset CLAUDE_CODE_DISABLE_AUTO_MEMORY

for f in tools aliases functions prompt; do  # order matters: tools first, prompt (warnings) last
    source "$HOME/.dotfiles/shell-tools/$f.sh"
done
unset f
