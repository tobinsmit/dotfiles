# .zshrc: Run at start of every interactive shell
# Typically used for shell setup, aliases, functions, prompts, key bindings etc

MISSING_TOOLS=""

# ----------------------------------------
# Common aliases
# ----------------------------------------

unset CLAUDE_CODE_DISABLE_AUTO_MEMORY

# alias ls="ls -a --color=auto"
# alias ll="ls -alD %Y-%m-%d"
# alias lw="ls -lD %Y-%d-%m --color=auto ~/monos"
alias ls="eza"
alias ll="eza -laF --git-repos-no-status --group-directories-first"
# alias lr="eza -l --git-repos-no-status"
# alias py="$(brew --prefix)/opt/python@3.10/bin/python3.10"

# alias tobin-prune="git fetch --prune && git branch --v | grep '\[gone\]' | awk '{print \$1}' | xargs git branch -D"

tobin-prune() {
    # Prune all branches that have been deleted on the remote
    echo "Fetching remote branches..."
    git fetch --prune

    # List branches that can be deleted
    branches=$(git branch --v | grep '\[gone\]' | awk '{print ($1 == "*") ? $2 : $1}')

    # If no branches can be deleted, exit
    if [ -z "$branches" ]; then
        echo "No branches can be deleted."
        return
    fi

    # Check if current branch is in the delete list
    current_branch=$(git branch --show-current)
    on_deletable=false
    if echo "$branches" | grep -qx "$current_branch"; then
        on_deletable=true
    fi

    # Ask user to continue
    echo "The following branches can be deleted:"
    echo "$branches" | sed 's/^/  /'
    if [ "$on_deletable" = true ]; then
        echo -n "This will switch to master and delete these branches. Continue? (Y/n): "
    else
        echo -n "Are you sure you want to delete these branches? (Y/n): "
    fi
    read confirm
    if [ "$confirm" != "Y" ] && [ "$confirm" != "" ]; then
        echo "Aborting."
        return
    fi

    # Switch to master if needed
    if [ "$on_deletable" = true ]; then
        git checkout master || { echo "Failed to switch to master. Aborting."; return 1; }
    fi

    # Delete the branches
    echo "$branches" | xargs git branch -D
}

# # Function to list git repositories and their current branches
# tobin-list-repos() {
#   local current_dir=$(pwd)
#
#   echo "Repositories in $current_dir:"
#   echo "--------------------------"
#
#   # Create a temporary file to store the output
#   local temp_file=$(mktemp)
#
#   # Loop through each directory
#   for dir in */; do
#     # Remove trailing slash
#     repo=${dir%/}
#
#     # Check if this is a git repository
#     if [ -d "$repo/.git" ]; then
#       # Get the current branch
#       cd "$repo"
#       branch=$(git branch --show-current)
#       echo "$repo\t$branch" >> "$temp_file"
#       cd ..
#     fi
#   done
#
#   # Display the results in columns
#   column -t -s $'\t' "$temp_file"
#
#   # Clean up
#   rm "$temp_file"
# }

tobin-code-list() {
    local current_dir=$(pwd)

    cd ~/code

    for dir in */; do
        echo "$dir"

        cd "$dir"
        # check if there is a .git directory
        if [ -d ".git" ]; then
            git branch | sed 's/^/  /'
        else
            echo "  No git repository"
        fi
        cd ..
    done

    cd "$current_dir"
}

# Delete Python venvs & cache dirs under the given path (default: .)
tobin-python-nuke() {
  local root="${1:-.}"

  local find_args=(
    "$root" -maxdepth "${2:-6}" -type d
    \( -name "venv" -o -name ".venv" -o -name "__pycache__"
       -o -name ".mypy_cache" -o -name ".pytest_cache" -o -name ".ruff_cache" \)
    -prune
  )

  echo "🔍 Searching for Python venvs & caches under: $root"
  find "${find_args[@]}" -print

  echo
  printf "⚠️  Delete ALL of these directories? [y/N] "
  read -r reply
  case "$reply" in
    [Yy]* )
      if ! command -v trash &> /dev/null; then
        echo "❌ 'trash' not found. Install with: brew install trash"
        return 1
      fi
      echo "🧨 Trashing…"
      find "${find_args[@]}" -exec sh -c 'trash "$1" && echo "  Trashed $1"' _ {} \;
      echo "✅ Done."
      ;;
    * )
      echo "❎ Aborted."
      ;;
  esac
}

# Delete node_modules dirs under the given path (default: .)
tobin-node-nuke() {
  local root="${1:-.}"

  local find_args=(
    "$root" -maxdepth "${2:-6}" -type d -name "node_modules"
    -prune
  )

  echo "🔍 Searching for node_modules under: $root"
  find "${find_args[@]}" -print

  echo
  printf "⚠️  Delete ALL of these directories? [y/N] "
  read -r reply
  case "$reply" in
    [Yy]* )
      if ! command -v trash &> /dev/null; then
        echo "❌ 'trash' not found. Install with: brew install trash"
        return 1
      fi
      echo "🧨 Trashing…"
      find "${find_args[@]}" -exec sh -c 'trash "$1" && echo "  Trashed $1"' _ {} \;
      echo "✅ Done."
      ;;
    * )
      echo "❎ Aborted."
      ;;
  esac
}

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

    setopt PROMPT_SUBST ; PS1='%F{green}ts %B%F{cyan}%~ %b%F{yellow}$(git_prompt)%B%F{141}%# %f%b'
else
    # Fallback to old prompt if git-prompt.sh is not available
    MISSING_TOOLS="$MISSING_TOOLS  .git-prompt.sh \n"
    PS1='%F{green}ts %B%F{cyan}%~ %F{141}%# %f%b'
fi

# ----------------------------------------
# Dotfiles
# ----------------------------------------

alias dotfiles='git --git-dir=$HOME/.dotfiles/.git --work-tree=$HOME'

# ----------------------------------------
# 3rd party add-ons
# ----------------------------------------

# Zsh auto completion
autoload -Uz compinit && compinit

# Fuzzy finder (fzf)
if which fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
else
    MISSING_TOOLS="$MISSING_TOOLS  fzf \n"
fi

# Syntax highlighting
zsh_high_path="$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
if [ -f "$zsh_high_path" ]; then
    source "$zsh_high_path"
else
    MISSING_TOOLS="$MISSING_TOOLS  zsh-syntax-highlighting \n"
fi

# Check if alt-tab not installed via brew
if [ ! -d "/Applications/AltTab.app" ]; then
    MISSING_TOOLS="$MISSING_TOOLS  alt-tab \n"
fi

# Check if coreutils is installed via brew
# Mostly just want it for timeout
# if ! brew list --formula | grep -q coreutils; then
#     MISSING_TOOLS="$MISSING_TOOLS  coreutils \n"
# fi

if [ -n "$MISSING_TOOLS" ]; then
    echo "\n🥵 Missing tools:"
    echo "$MISSING_TOOLS"
    echo "✨ To install missing tools, run:"
    echo "  source ~/.dotfiles/install_tools.sh"
fi


# Terminal title management functions
# https://www.wiserfirst.com/blog/taking-control-of-terminal-titles/
terminal_titles() {
    case "$1" in
        window)
            echo -ne "\033]2;$2\007"
            ;;
        tab)
            echo -ne "\033]1;$2\007"
            ;;
        both)
            echo -ne "\033]0;$2\007"
            ;;
        help)
            echo "Usage: terminal_titles [window|tab|both|reset|help] [title]"
            echo "  window [title] - Set window title only"
            echo "  tab [title]    - Set tab title only"
            echo "  both [title]   - Set both window and tab to same title"
            echo "  reset          - Reset to default titles"
            echo "  help           - Show this help message"
            echo "  (no args)      - Same as reset"
            ;;
        reset|"")
            # Window title: full path with ~ for home
            echo -ne "\033]2;${PWD/#$HOME/~}\007"
            # Tab title: last portion of the full path
            echo -ne "\033]1;${PWD##*/}\007"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use 'terminal_titles help' for usage"
            ;;
    esac
}

# Alias for convenience
#alias tt='terminal_titles'
