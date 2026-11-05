# Shell functions (tobin-* cleanup helpers, terminal titles). Sourced by common_run_commands.sh

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

    # Run repo maintenance (gc, commit-graph, etc.)
    git maintenance run --quiet 2>/dev/null || true
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

# Delete the given newline-separated list of directories using either `trash`
# or `rm -rf`. Honours $TOBIN_NUKE_DELETER if set (values: trash | rm),
# otherwise prompts the user. Times the deletion loop.
_tobin-nuke-delete-all() {
  local matches="$1"
  local deleter="$TOBIN_NUKE_DELETER"
  local had_errors=0
  local target reply

  if [ -z "$deleter" ]; then
    printf "⚠️  Delete ALL of these directories? [t]rash / [r]m -rf / [N]o "
    read -r reply
    case "$reply" in
      [Tt]* ) deleter=trash ;;
      [Rr]* ) deleter=rm ;;
      * ) echo "❎ Aborted."; return 0 ;;
    esac
  fi

  if [ "$deleter" = "trash" ] && ! command -v trash &> /dev/null; then
    echo "❌ 'trash' not found. Install with: brew install trash"
    return 1
  fi

  echo "🧨 Deleting with $deleter…"
  SECONDS=0
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    if [ "$deleter" = "trash" ]; then
      if trash "$target"; then
        echo "  Trashed $target"
      else
        echo "  Failed to trash $target"
        had_errors=1
      fi
    else
      if rm -rf "$target"; then
        echo "  Removed $target"
      else
        echo "  Failed to rm $target"
        had_errors=1
      fi
    fi
  done <<< "$matches"
  echo "⏱  ${SECONDS}s"
  if [ "$had_errors" -eq 0 ]; then
    echo "✅ Done."
  else
    echo "❌ Finished with errors."
    return 1
  fi
}

# Delete Python venvs & cache dirs under the given path (default: .)
tobin-python-nuke() {
  local root="${1:-.}"
  local maxdepth="${2:-10}"
  local matches

  matches="$(
    find "$root" -maxdepth "$maxdepth" -type d \
      \( -name "venv" -o -name ".venv" -o -name "__pycache__" \
         -o -name ".mypy_cache" -o -name ".pytest_cache" -o -name ".ruff_cache" \) \
      -prune -print
  )"

  echo "🔍 Searching for Python venvs & caches under: $root"
  printf '%s\n' "$matches"

  if [ -z "$matches" ]; then
    echo "✅ No Python venvs or caches found."
    return 0
  fi

  echo
  _tobin-nuke-delete-all "$matches"
}

# Delete orphaned pipenv virtualenvs from the shared virtualenv store.
# pipenv keys each env to the absolute path of its project, so every deleted
# git worktree strands its (often ~1GB) env behind with nothing pointing at it.
# An env is orphaned when the path recorded in its .project file is gone.
# Envs with no .project file are left alone — we only delete what we can verify.
tobin-orphan-venv-nuke() {
  local venv_home="${WORKON_HOME:-$HOME/.local/share/virtualenvs}"
  local matches project d

  if [ ! -d "$venv_home" ]; then
    echo "✅ No pipenv virtualenv store at: $venv_home"
    return 0
  fi

  matches="$(
    for d in "$venv_home"/*/; do
      [ -d "$d" ] || continue
      project="$(cat "${d}.project" 2>/dev/null)"
      [ -n "$project" ] || continue
      [ -d "$project" ] || printf '%s\n' "${d%/}"
    done
  )"

  echo "🔍 Searching for orphaned pipenv virtualenvs under: $venv_home"
  printf '%s\n' "$matches"

  if [ -z "$matches" ]; then
    echo "✅ No orphaned virtualenvs found."
    return 0
  fi

  echo
  _tobin-nuke-delete-all "$matches"
}

# Delete node_modules dirs under the given path (default: .)
tobin-node-nuke() {
  local root="${1:-.}"
  local maxdepth="${2:-10}"
  local matches

  matches="$(
    find "$root" -maxdepth "$maxdepth" -type d -name "node_modules" -prune -print
  )"

  echo "🔍 Searching for node_modules under: $root"
  printf '%s\n' "$matches"

  if [ -z "$matches" ]; then
    echo "✅ No node_modules directories found."
    return 0
  fi

  echo
  _tobin-nuke-delete-all "$matches"
}

# Delete gitignored files under the given path (default: .)
tobin-gitignored-nuke() {
  local root="${1:-.}"
  local had_errors=0
  local original_dir="$PWD"

  if ! command -v git &> /dev/null; then
    echo "❌ 'git' not found."
    return 1
  fi

  if ! [ -d "$root" ]; then
    echo "❌ Directory not found: $root"
    return 1
  fi

  if ! (
    cd "$root" 2>/dev/null || exit 1
    git rev-parse --is-inside-work-tree >/dev/null 2>&1
  ); then
    echo "❎ Skipping gitignored cleanup: $root is not inside a git work tree."
    return 0
  fi

  echo "🔍 Searching for gitignored files under: $root"
  local ignored_files
  ignored_files="$(
    cd "$root" &&
    git ls-files --others -i --exclude-standard --directory
  )"
  printf '%s\n' "$ignored_files"

  if [ -z "$ignored_files" ]; then
    echo "✅ No gitignored files found."
    return 0
  fi

  echo
  local deleter="${TOBIN_NUKE_DELETER:-trash}"
  local reply
  if [ -n "$TOBIN_NUKE_DELETER" ]; then
    reply=y
  else
    printf "⚠️  Delete ALL of these files? [y/N] "
    read -r reply
  fi
  case "$reply" in
    [Yy]* )
      if [ "$deleter" = "trash" ] && ! command -v trash &> /dev/null; then
        echo "❌ 'trash' not found. Install with: brew install trash"
        return 1
      fi
      echo "🧨 Deleting with $deleter…"
      cd "$root" || return 1
      while IFS= read -r target; do
        [ -n "$target" ] || continue
        if { [ "$deleter" = "trash" ] && trash "$target"; } || { [ "$deleter" = "rm" ] && rm -rf "$target"; }; then
          echo "  Deleted $target"
        else
          echo "  Failed to delete $target"
          had_errors=1
        fi
      done <<< "$ignored_files"
      cd "$original_dir" || return 1
      if [ "$had_errors" -eq 0 ]; then
        echo "✅ Done."
      else
        echo "❌ Finished with errors."
        return 1
      fi
      ;;
    * )
      echo "❎ Aborted."
      ;;
  esac
}

# Delete empty directories under the given path (default: .)
tobin-empty-dir-nuke() {
  local root="${1:-.}"
  local matches

  matches="$(find "$root" -depth -type d -empty -print)"

  echo "🔍 Searching for empty directories under: $root"
  printf '%s\n' "$matches"

  if [ -z "$matches" ]; then
    echo "✅ No empty directories found."
    return 0
  fi

  echo
  _tobin-nuke-delete-all "$matches"
}

# Run Python, Node, gitignored, and empty-dir cleanup under the given path (default: .)
# Usage: tobin-nuke [root] [maxdepth] [trash|rm]
# Passing the deleter as the third argument skips every prompt, so the function
# can be run non-interactively (e.g. from a script or an agent).
tobin-nuke() {
  local root="${1:-.}"
  local maxdepth="${2:-10}"
  local TOBIN_NUKE_DELETER="$3"
  local reply

  case "$TOBIN_NUKE_DELETER" in
    trash|rm ) ;;
    "" )
      printf "Use [t]rash or [r]m -rf? [t/r/N] "
      read -r reply
      case "$reply" in
        [Tt]* ) TOBIN_NUKE_DELETER=trash ;;
        [Rr]* ) TOBIN_NUKE_DELETER=rm ;;
        * ) echo "❎ Aborted."; return 0 ;;
      esac
      ;;
    * ) echo "❌ Unknown deleter '$TOBIN_NUKE_DELETER' (expected 'trash' or 'rm')."; return 1 ;;
  esac

  tobin-python-nuke "$root" "$maxdepth" || return $?
  echo
  tobin-node-nuke "$root" "$maxdepth" || return $?
  echo
  tobin-gitignored-nuke "$root" || return $?
  echo
  tobin-empty-dir-nuke "$root" || return $?
}

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
