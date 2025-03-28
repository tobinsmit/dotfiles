#!/bin/bash

# This script clones and sets up github.com/tobinsmit/dotfiles into $HOME

# It will:
# - backup your existing dotfiles
# - clone the repository to $HOME/.dotfiles
# - set up the 'dotfiles' alias for management


# We don't need return codes for "$(command)", only stdout is needed.
# shellcheck disable=SC2312

set -e  # Exit on error
set -u  # Treat unset variables as errors

# Define variables
DOTFILES_REPO="https://github.com/tobinsmit/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
NONINTERACTIVE=${NONINTERACTIVE:-}
CI=${CI:-} # CI is set by GitHub Actions

# string formatters
if [[ -t 1 ]]
then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

# Utility functions

shell_join() {
  # Join arguments into a single string
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"
  do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

chomp() {
  # Remove trailing newline characters from the input
  printf "%s" "${1/"$'\n'"/}"
}

ohai() {
  # Print a message in blue
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

warn() {
  # Print a warning message in red
  printf "${tty_red}Warning${tty_reset}: %s\n" "$(chomp "$1")" >&2
}

abort() {
  # Print an error message in red
  printf "${tty_red}Error${tty_reset}: %s\n" "$(chomp "$1")" >&2
  exit 1
}

# Check if running in non-interactive mode
if [[ -z "${NONINTERACTIVE-}" ]]
then
  if [[ -n "${CI-}" ]]
  then
    warn 'Running in non-interactive mode because $CI is set.'
    NONINTERACTIVE=1
  elif [[ ! -t 0 ]]
  then
    warn 'Running in non-interactive mode because stdin is not a TTY.'
    NONINTERACTIVE=1
  fi
else
  ohai 'Running in non-interactive mode because $NONINTERACTIVE is set.'
fi

# Ask for confirmation unless running non-interactively
wait_for_user() {
  if [[ -n "${NONINTERACTIVE-}" ]]
  then
    return
  fi
  
  local c
  echo
  echo "Press ${tty_bold}RETURN${tty_reset}/${tty_bold}ENTER${tty_reset} to continue or any other key to abort:"
  getc c
  # we test for \r and \n because some stuff does \r instead
  if ! [[ "${c}" == $'\r' || "${c}" == $'\n' ]]
  then
    exit 1
  fi
}

getc() {
  local save_state
  save_state="$(/bin/stty -g)"
  /bin/stty raw -echo
  IFS='' read -r -n 1 -d '' "$@"
  /bin/stty "${save_state}"
}

# Create backup of existing dotfiles
backup_existing_dotfiles() {
  ohai "Creating backup of existing dotfiles..."
  mkdir -p "$BACKUP_DIR"
  
  # List of common dotfiles to back up
  dotfiles=(".zshrc" ".bashrc" ".gitconfig" ".vimrc" ".tmux.conf" ".profile")
  
  for file in "${dotfiles[@]}"; do
    if [ -f "$HOME/$file" ]; then
      echo "  Backing up $file"
      cp "$HOME/$file" "$BACKUP_DIR/"
    fi
  done
  
  echo "✅ Backup created at $BACKUP_DIR"
}

# Clone the dotfiles repository
clone_repo() {
  ohai "Cloning dotfiles repository..."
  if [ -d "$DOTFILES_DIR" ]; then
    warn "Directory $DOTFILES_DIR already exists!"
    echo "Would you like to remove it and clone again? (y/n)"
    if [[ -z "${NONINTERACTIVE-}" ]]; then
      read -r response
      if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        rm -rf "$DOTFILES_DIR"
      else
        abort "Aborted by user"
      fi
    else
      warn "Removing existing directory in non-interactive mode"
      rm -rf "$DOTFILES_DIR"
    fi
  fi
  
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"

}

configure_git() {
  ohai "Configuring git..."
  git -C "$DOTFILES_DIR" config --local status.showUntrackedFiles no
}

# Set up run commands
setup_run_commands() {
  ohai "Setting up run commands..."
  
  # Determine which shell configuration file to use
  if [ -n "$SHELL" ]; then
    case "$SHELL" in
      */bash)
        SHELL_CONFIG="$HOME/.bashrc"
        ;;
      */zsh)
        SHELL_CONFIG="$HOME/.zshrc"
        ;;
      *)
        SHELL_CONFIG="$HOME/.profile"
        ;;
    esac
  elif [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
  elif [ -f "$HOME/.bashrc" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
  else
    SHELL_CONFIG="$HOME/.profile"
    touch "$SHELL_CONFIG"
  fi
  
  # Add source command to shell config if it doesn't exist
  if ! grep -q "source.*common_run_commands.sh" "$SHELL_CONFIG"; then
    echo "# Source common shell commands" >> "$SHELL_CONFIG"
    echo "source $DOTFILES_DIR/common_run_commands.sh" >> "$SHELL_CONFIG"
    echo "✅ Added source command to $SHELL_CONFIG"
  else
    echo "ℹ️ Source command already exists in $SHELL_CONFIG"
  fi
}

# Main execution
ohai "This script will install dotfiles from $DOTFILES_REPO"
ohai "It will:"
echo "- Back up your existing $DOTFILES_DIR to $BACKUP_DIR"
echo "- Clone and configure the repository to $DOTFILES_DIR"
echo "- Set up common run commands"

if [[ -z "${NONINTERACTIVE-}" ]]; then
  wait_for_user
fi

main() {
  backup_existing_dotfiles
  clone_repo
  configure_git
  setup_run_commands
  
  ohai "🎉 Dotfiles installation complete!"
  ohai "What's next:"
  echo "1. Source your shell configuration: "
  echo "   source $SHELL_CONFIG"
  echo "2. Use 'dotfiles' command to manage your dotfiles:"
  echo "   - dotfiles status"
  echo "   - dotfiles add ~/.some_config"
  echo "   - dotfiles commit -m \"Add some config\""
  echo "   - dotfiles push"
}

main