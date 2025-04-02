# .zshrc: Run at start of every interactive shell
# Typically used for shell setup, aliases, functions, prompts, key bindings etc

MISSING_TOOLS=""

# ----------------------------------------
# Common aliases
# ----------------------------------------

alias ls="ls -a --color=auto"
alias ll="ls -alD %Y-%m-%d"
alias lw="ls -lD %Y-%d-%m --color=auto ~/monos"
# alias py="$(brew --prefix)/opt/python@3.10/bin/python3.10"

# alias tobin-prune="git fetch --prune && git branch --v | grep '\[gone\]' | awk '{print \$1}' | xargs git branch -D"

tobin-prune() {
    # Prune all branches that have been deleted on the remote
    echo "Fetching remote branches..."
    git fetch --prune

    # List branches that can be deleted
    branches=$(git branch --v | grep '\[gone\]' | awk '{print $1}')

    # If no branches can be deleted, exit
    if [ -z "$branches" ]; then
        echo "No branches can be deleted."
        return
    fi

    # Ask user to continue
    echo "The following branches can be deleted:"
    echo "$branches" | sed 's/^/  /'
    echo -n "Are you sure you want to delete these branches? (Y/n): "
    read confirm
    if [ "$confirm" != "Y" ] && [ "$confirm" != "" ]; then
        echo "Aborting."
        return
    fi

    # Delete the branches
    echo "$branches" | xargs git branch -D
}

# Function to list git repositories and their current branches
tobin-list-repos() {
  local current_dir=$(pwd)
    
  echo "Repositories in $current_dir:"
  echo "--------------------------"
    
  # Create a temporary file to store the output
  local temp_file=$(mktemp)
    
  # Loop through each directory
  for dir in */; do
    # Remove trailing slash
    repo=${dir%/}
    
    # Check if this is a git repository
    if [ -d "$repo/.git" ]; then
      # Get the current branch
      cd "$repo"
      branch=$(git branch --show-current)
      echo "$repo\t$branch" >> "$temp_file"
      cd ..
    fi
  done
  
  # Display the results in columns
  column -t -s $'\t' "$temp_file"
  
  # Clean up
  rm "$temp_file"
  
  # Return to original directory
  cd "$current_dir"
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

if [ -n "$MISSING_TOOLS" ]; then
    echo "\n🥵 Missing tools:"
    echo "$MISSING_TOOLS"
    echo "✨ To install missing tools, run:"
    echo "  source ~/.dotfiles/install_tools.sh"
fi
