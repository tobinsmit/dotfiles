# Aliases. Sourced by common_run_commands.sh

# alias ls="ls -a --color=auto"
# alias ll="ls -alD %Y-%m-%d"
if command -v eza >/dev/null 2>&1; then
    alias ls="eza"
    alias ll="eza -laF --git-repos-no-status --group-directories-first"
else
    alias ll="ls -laF"  # fallback until eza is installed
fi
# alias lr="eza -l --git-repos-no-status"
# alias py="$(brew --prefix)/opt/python@3.10/bin/python3.10"


# Alias for convenience
#alias tt='terminal_titles'
