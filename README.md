🛠️ This is a repo for common tools, scripts, etc that I use at work and at home 🏡

My config files live here when they're not crashing my terminal

> [!WARNING]
> **This is a public repo.** Don't commit anything personal or private: no secrets, tokens, emails, work/org identifiers, or machine-specific paths (use `~`/`$HOME`). Put machine-specific or private settings in your untracked `~/.zshrc` instead. Commits use your GitHub no-reply email (set automatically by `install_tools.sh`).

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

## Layout

| Path | What it is | Where to add things |
|---|---|---|
| `install_dotfiles.sh` | Backs up existing dotfiles to `~/.dotfiles-backups/<timestamp>/` (never pruned), clones or updates the repo, sets up shell sourcing, runs `install_tools.sh` | |
| `install_tools.sh` | Installs missing tools (needs Homebrew), sets git name + GitHub no-reply email from the GitHub API if unset, links VSCode/Cursor settings, points iTerm2 at its settings folder | New app setup steps |
| `common_run_commands.sh` | Entry point sourced from `~/.zshrc`; loads `shell-tools/*.sh` | Nothing (keep it tiny) |
| `shell-tools/tools.sh` | List of tools the shell expects, with install checks. Read by the startup warning and `install_tools.sh` | New tools |
| `shell-tools/aliases.sh` | Aliases | New aliases |
| `shell-tools/functions.sh` | Shell functions: `tobin-prune`, `tobin-code-list`, `tobin-*-nuke`, `terminal_titles` | New functions |
| `shell-tools/prompt.sh` | Prompt, completion, fzf, syntax highlighting, missing-tools warning | Prompt / add-on changes |
| `shell-tools/audit-claude-settings.py` | Audits Claude Code permission rules across `~/code/` and removes duplicates of global settings: `uv run python ~/.dotfiles/shell-tools/audit-claude-settings.py [--apply]` | |
| `apps/vscode/` | VSCode/Cursor settings and keybindings, **symlinked** into the editor, so changes made in the editor land in the repo | |
| `apps/iterm2/` | iTerm2 settings. iTerm2 **loads them from this folder** (set by `install_tools.sh`) | |

There are no tests, linting, or build steps.

Tobin can make mistakes. Please double-check responses. 😉
