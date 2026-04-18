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
    # Parse flags
    local dry_run=false force=false verbose=false
    for arg in "$@"; do
        case "$arg" in
            --dry-run) dry_run=true ;;
            --force) force=true ;;
            --verbose|-v) verbose=true ;;
        esac
    done

    # Prune all branches that have been deleted on the remote
    echo -n "Fetching..."
    if [ "$verbose" = true ]; then
        echo ""
        git fetch --prune
    else
        git fetch --prune --quiet 2>/dev/null
        echo -ne "\r\033[K"
    fi

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

    # Show branches, mimicking git branch format
    echo "The following branches can be deleted:"
    while IFS= read -r branch; do
        if [ "$branch" = "$current_branch" ]; then
            echo "* $branch"
        else
            echo "  $branch"
        fi
    done <<< "$branches"

    # Dry run: just show, don't delete
    if [ "$dry_run" = true ]; then
        return
    fi

    # Prompt unless --force
    if [ "$force" != true ]; then
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
    fi

    # Switch to master if needed
    if [ "$on_deletable" = true ]; then
        git checkout master --quiet || { echo "Failed to switch to master. Aborting."; return 1; }
        git pull --quiet 2>/dev/null
    fi

    # Delete the branches
    echo "$branches" | xargs git branch -D
}

tobin-prune-all() {
    local flag=""
    for arg in "$@"; do
        case "$arg" in
            --dry-run|--force) flag="$arg" ;;
            *) ;;
        esac
    done

    local original_dir=$(pwd)

    # Get current remote master hash with a single network call
    local any_repo=$(find ~/code -maxdepth 2 -name .git -type d -print -quit)
    local remote_hash=""
    if [ -n "$any_repo" ]; then
        remote_hash=$(git -C "${any_repo%/.git}" ls-remote --quiet origin master 2>/dev/null | awk '{print $1}')
    fi

    local skipped=0

    for dir in ~/code/*/; do
        [ -d "$dir.git" ] || continue
        local name=$(basename "$dir")

        # Skip repos whose origin/master already matches remote
        if [ -n "$remote_hash" ]; then
            local local_hash=$(git -C "$dir" rev-parse origin/master 2>/dev/null)
            if [ "$local_hash" = "$remote_hash" ]; then
                # Still check for existing [gone] branches without fetching
                local gone=$(git -C "$dir" branch -vv 2>/dev/null | grep '\[.*: gone\]')
                if [ -z "$gone" ]; then
                    echo "\n--- $name --- (up to date)"
                    skipped=$((skipped + 1))
                    continue
                fi
            fi
        fi

        echo "\n--- $name ---"
        cd "$dir"
        tobin-prune $flag
        cd "$original_dir"
    done

    if [ "$skipped" -gt 0 ]; then
        echo "\nSkipped $skipped repos (already up to date)"
    fi
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
    local BOLD=$'\033[1m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' NC=$'\033[0m'
    local clean=0 feature=0

    for dir in ~/code/*/; do
        [ -d "$dir.git" ] || continue
        local name=$(basename "$dir")
        local current=$(git -C "$dir" branch --show-current 2>/dev/null)

        # Build branch list with current branch coloured
        local branch_list=""
        while IFS= read -r line; do
            local is_current=false
            local branch=$(echo "$line" | sed 's/^[* ] //')
            [[ "$line" == \** ]] && is_current=true

            if $is_current; then
                if [[ "$branch" == "master" ]]; then
                    branch_list+="${BOLD}${GREEN}${branch}${NC} "
                else
                    branch_list+="${BOLD}${YELLOW}${branch}${NC} "
                fi
            else
                branch_list+="$branch "
            fi
        done < <(git -C "$dir" branch 2>/dev/null)

        echo "${BOLD}${name}${NC}  $branch_list"

        if [[ "$current" == "master" ]]; then
            clean=$((clean + 1))
        else
            feature=$((feature + 1))
        fi
    done

    echo ""
    echo "$clean on master, $feature on feature branches"
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

    setopt PROMPT_SUBST ; PS1='%F{green}${PROMPT_LABEL:-ts} %B%F{cyan}%~ %b%F{yellow}$(git_prompt)%B%F{141}%# %f%b'
else
    # Fallback to old prompt if git-prompt.sh is not available
    MISSING_TOOLS="$MISSING_TOOLS  .git-prompt.sh \n"
    PS1='%F{green}${PROMPT_LABEL:-ts} %B%F{cyan}%~ %F{141}%# %f%b'
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
