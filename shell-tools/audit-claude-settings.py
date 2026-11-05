#!/usr/bin/env python3
"""Audit Claude Code settings.local.json files across workspaces."""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

# Config
CODE_DIR = Path.home() / "code"
GLOBAL_SETTINGS = Path.home() / ".claude" / "settings.json"
apply_mode = "--apply" in sys.argv

# ANSI colors
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
NC = "\033[0m"

if not GLOBAL_SETTINGS.exists():
    print(f"{RED}Global settings not found: {GLOBAL_SETTINGS}{NC}")
    sys.exit(1)

# 1. Load global settings once
global_data = json.loads(GLOBAL_SETTINGS.read_text())
global_allows = set(global_data.get("permissions", {}).get("allow", []))
global_mcp_enabled = global_data.get("enableAllProjectMcpServers", False)
global_mcp_servers = set(global_data.get("enabledMcpjsonServers", []))


def is_duplicate(rule: str) -> bool:
    """Check if a local rule is covered by global settings (exact or wildcard)."""
    if rule in global_allows:
        return True
    for g in global_allows:
        if g.endswith(":*") and rule.startswith(g[:-1]):
            return True
    return False


print(f"{BOLD}Claude Code Settings Audit{NC}")
print(f"Global settings: {GLOBAL_SETTINGS}")
print()

total = 0
clean = 0
has_dupes = 0
empty = 0

# Collect unique rules: rule -> list of (workspace, settings_path)
all_unique: dict[str, list[tuple[str, Path]]] = {}
modified_locals: dict[Path, dict] = {}

# 2. Scan all workspaces
for settings_path in sorted(CODE_DIR.glob("*/.claude/settings.local.json")):
    workspace = settings_path.parent.parent.name
    try:
        local_data = json.loads(settings_path.read_text())
    except (json.JSONDecodeError, OSError):
        continue

    total += 1

    local_allows = local_data.get("permissions", {}).get("allow", [])
    local_mcp_enabled = local_data.get("enableAllProjectMcpServers", None)
    local_mcp_servers = local_data.get("enabledMcpjsonServers", [])

    # Classify permission rules
    dupes = []
    uniques = []
    for p in local_allows:
        if is_duplicate(p):
            dupes.append(p)
        else:
            uniques.append(p)

    # Classify MCP duplicates
    mcp_dupes = []
    if local_mcp_enabled is not None and global_mcp_enabled:
        mcp_dupes.append("enableAllProjectMcpServers")
    for s in local_mcp_servers:
        if s in global_mcp_servers:
            mcp_dupes.append(f"enabledMcpjsonServers:{s}")

    if not dupes and not mcp_dupes and not uniques:
        empty += 1
        continue

    if not dupes and not mcp_dupes:
        clean += 1
    else:
        has_dupes += 1

    print(f"{CYAN}{workspace}{NC}")

    for d in dupes:
        print(f"  {RED}duplicate:{NC} {d}")
    for m in mcp_dupes:
        print(f"  {RED}duplicate:{NC} {m}")
    for u in uniques:
        print(f"  {GREEN}unique:{NC} {u}")
        all_unique.setdefault(u, []).append((workspace, settings_path))

    # Clean duplicates if --apply
    if apply_mode and (dupes or mcp_dupes):
        filtered = [p for p in local_allows if not is_duplicate(p)]
        local_data.setdefault("permissions", {})["allow"] = filtered

        if global_mcp_enabled and "enableAllProjectMcpServers" in local_data:
            del local_data["enableAllProjectMcpServers"]
        if "enabledMcpjsonServers" in local_data:
            remaining = [s for s in local_data["enabledMcpjsonServers"] if s not in global_mcp_servers]
            if remaining:
                local_data["enabledMcpjsonServers"] = remaining
            else:
                del local_data["enabledMcpjsonServers"]

        modified_locals[settings_path] = local_data
        print(f"  {YELLOW}-> cleaned duplicates{NC}")

    print()

# 3. Write modified local files (--apply)
for path, data in modified_locals.items():
    path.write_text(json.dumps(data, indent=2) + "\n")

# 4. Summary
print(f"{BOLD}Summary{NC}")
print(f"  Total workspaces scanned: {total}")
print(f"  {GREEN}Clean (unique only):{NC} {clean}")
print(f"  {YELLOW}Empty (no permissions):{NC} {empty}")
print(f"  {RED}Has duplicates:{NC} {has_dupes}")
if not apply_mode and has_dupes > 0:
    print(f"  Run with {BOLD}--apply{NC} to remove duplicates.")

# 5. fzf promotion prompt
if not all_unique:
    sys.exit(0)

if not shutil.which("fzf"):
    print(f"\n{YELLOW}Install fzf for interactive rule promotion: brew install fzf{NC}")
    sys.exit(0)

# Build fzf lines: "rule  (workspace1, workspace2)"
fzf_lines = []
for rule, sources in sorted(all_unique.items()):
    workspaces = ", ".join(ws for ws, _ in sources)
    fzf_lines.append(f"{rule:<45}  ({workspaces})")

print(f"\n{BOLD}Promote unique rules to global settings{NC}")
print("Use Tab to toggle, Enter to confirm (empty = skip all)")
print()

try:
    result = subprocess.run(
        ["fzf", "--multi",
         "--header=Tab: toggle | Enter: confirm | Esc: skip all",
         "--prompt=Promote> ",
         "--height=~50%",
         "--reverse"],
        input="\n".join(fzf_lines),
        capture_output=True,
        text=True,
    )
    selected = result.stdout.strip()
except (OSError, subprocess.SubprocessError):
    selected = ""

if not selected:
    print(f"{YELLOW}No rules promoted.{NC}")
    sys.exit(0)

# Extract rule names (strip trailing whitespace and workspace suffix)
promote_rules = set()
for line in selected.splitlines():
    # Strip "  (workspace1, workspace2)" suffix
    rule = line.split("  (")[0].rstrip()
    if rule:
        promote_rules.add(rule)

# Update global settings
allow_list = global_data.setdefault("permissions", {}).setdefault("allow", [])
for p in promote_rules:
    if p not in allow_list:
        allow_list.append(p)
allow_list.sort()
GLOBAL_SETTINGS.write_text(json.dumps(global_data, indent=2) + "\n")

# Remove promoted rules from local settings files
for settings_path in CODE_DIR.glob("*/.claude/settings.local.json"):
    try:
        local_data = json.loads(settings_path.read_text())
        local_allows = local_data.get("permissions", {}).get("allow", [])
        filtered = [p for p in local_allows if p not in promote_rules]
        if len(filtered) != len(local_allows):
            local_data["permissions"]["allow"] = filtered
            settings_path.write_text(json.dumps(local_data, indent=2) + "\n")
    except (json.JSONDecodeError, OSError):
        pass

print()
for p in sorted(promote_rules):
    print(f"{YELLOW}-> promoted:{NC} {p}")
print()
print(f"{GREEN}Done. {len(promote_rules)} rule(s) promoted to global settings.{NC}")
