# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Architecture

This is a **bare git repository** for managing dotfiles across `$HOME`. The git metadata lives at `~/.dotfiles/.git` and the work tree is `$HOME` itself.

**Key concept:** Files tracked by this repo are scattered throughout the home directory, not colocated in `.dotfiles/`.

### Git Alias

All git operations use the `dotfiles` alias instead of `git`:

```bash
alias dotfiles='git --git-dir=$HOME/.dotfiles/.git --work-tree=$HOME'
```

Examples: `dotfiles status`, `dotfiles add ~/.zshrc`, `dotfiles commit -m "msg"`, `dotfiles push`

Untracked files are hidden by default (`status.showUntrackedFiles no`).

## Key Files

- **install.sh** — Installation script: clones bare repo, backs up existing dotfiles, sets up shell sourcing
- **common_run_commands.sh** — Shell config sourced at startup: aliases, prompt, utility functions (`tobin-prune`, `tobin-code-list`, `tobin-python-nuke`, `tobin-node-nuke`, `terminal_titles`)
- **audit-claude-settings.py** — Audits Claude Code permission rules across `~/code/` workspaces, deduplicates against global settings. Run: `uv run python audit-claude-settings.py [--apply]`
- **vscode-settings/** — VSCode/Cursor settings and keybindings (synced manually, not symlinked)

## Commands

```bash
dotfiles status          # Check repo status
dotfiles diff            # View changes
dotfiles add <file>      # Stage a file (use absolute path from $HOME)
dotfiles commit -m "msg" # Commit
dotfiles push            # Push to origin

uv run python audit-claude-settings.py         # Audit claude settings (dry run)
uv run python audit-claude-settings.py --apply # Audit and remove duplicates
```

There are no tests, linting, or build steps.
