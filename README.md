🛠️ This is a repo for common tools, scripts, etc that I use at work and at home 🏡

My config files live here when they're not crashing my terminal

## Install

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/tobinsmit/dotfiles/main/install_dotfiles.sh)"
```

This backs up existing dotfiles, clones the repo over HTTPS (then switches `origin` to SSH for pushing), and runs `install_tools.sh`. Re-running it is safe: an existing clone is fast-forwarded, never deleted.

To just install missing tools, set git identity, and link editor settings (also safe to re-run):

```bash
source ~/.dotfiles/install_tools.sh
```

## How it works

This is a regular git repo cloned to `~/.dotfiles`. Use plain `git` from inside that directory to commit and push changes.

Files are not symlinked into `$HOME`. Instead, `install_dotfiles.sh` appends `source ~/.dotfiles/common_run_commands.sh` to your shell config (e.g. `~/.zshrc`). That shell config stays untracked and machine-specific, e.g. for setting `PROMPT_LABEL`.

## Key files

- **install_dotfiles.sh**: backs up existing dotfiles to `~/.dotfiles-backups/<timestamp>/` (never pruned), clones the repo to `~/.dotfiles`, and sets up shell sourcing
- **install_tools.sh**: installs missing tools (needs Homebrew), sets git name and GitHub no-reply email from the GitHub API if unset, and symlinks VSCode/Cursor settings into `vscode-settings/`
- **tools.sh**: the list of tools the shell config expects. Add new tools here; both the startup "missing tools" warning and `install_tools.sh` read it
- **common_run_commands.sh**: shell config sourced at startup: aliases, prompt, and utility functions (`tobin-prune`, `tobin-code-list`, `tobin-python-nuke`, `tobin-node-nuke`, `terminal_titles`)
- **audit-claude-settings.py**: audits Claude Code permission rules across `~/code/` workspaces and removes duplicates of global settings
  ```bash
  uv run python audit-claude-settings.py         # dry run
  uv run python audit-claude-settings.py --apply # remove duplicates
  ```
- **vscode-settings/**: VSCode/Cursor settings and keybindings. The editor's user settings are symlinked here by `install_tools.sh`, so changes made in the editor land in the repo
- **com.googlecode.iterm2.plist**: iTerm2 preferences

There are no tests, linting, or build steps.

Tobin can make mistakes. Please double-check responses. 😉
