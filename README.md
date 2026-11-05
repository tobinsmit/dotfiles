🛠️ This is a repo for common tools, scripts, etc that I use at work and at home 🏡

My config files live here when they're not crashing my terminal

## Install

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/tobinsmit/dotfiles/main/install.sh)"
```

Then install any missing tools the shell config expects (e.g. `.git-prompt.sh`):

```bash
source ~/.dotfiles/install_tools.sh
```

## How it works

This is a regular git repo cloned to `~/.dotfiles`. Use plain `git` from inside that directory to commit and push changes.

Files are not symlinked into `$HOME`. Instead, `install.sh` appends `source ~/.dotfiles/common_run_commands.sh` to your shell config (e.g. `~/.zshrc`). That shell config stays untracked and machine-specific, e.g. for setting `PROMPT_LABEL`.

## Key files

- **install.sh**: clones the repo to `~/.dotfiles`, backs up existing dotfiles, and sets up shell sourcing
- **install_tools.sh**: installs tools referenced by `common_run_commands.sh` that are missing
- **common_run_commands.sh**: shell config sourced at startup: aliases, prompt, and utility functions (`tobin-prune`, `tobin-code-list`, `tobin-python-nuke`, `tobin-node-nuke`, `terminal_titles`)
- **audit-claude-settings.py**: audits Claude Code permission rules across `~/code/` workspaces and removes duplicates of global settings
  ```bash
  uv run python audit-claude-settings.py         # dry run
  uv run python audit-claude-settings.py --apply # remove duplicates
  ```
- **vscode-settings/**: VSCode/Cursor settings and keybindings (synced manually, not symlinked)
- **com.googlecode.iterm2.plist**: iTerm2 preferences

There are no tests, linting, or build steps.

Tobin can make mistakes. Please double-check responses. 😉
