#!/usr/bin/env bash
# Mounts the canonical factory into Codex's repo-skill discovery path.
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p .agents/skills
for d in agents/skills/*/; do
  name=$(basename "$d")
  expected="../../agents/skills/$name"
  target=".agents/skills/$name"

  if [[ -L "$target" ]]; then
    actual=$(readlink "$target")
    if [[ "$actual" == "$expected" ]]; then
      continue
    fi

    printf 'Refusing to replace symlink %s -> %s (expected %s)\n' "$target" "$actual" "$expected" >&2
    exit 1
  fi

  if [[ -e "$target" ]]; then
    printf 'Refusing to replace existing path: %s\n' "$target" >&2
    exit 1
  fi

  ln -s "$expected" "$target"
done
ls -l .agents/skills
