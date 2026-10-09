#!/usr/bin/env bash
# État des dossiers de projets pour projets.qml : une ligne JSON par dossier.
# Usage : projets.sh <dossier des projets>

set -uo pipefail

for dir in "$1"/*/; do
  dir=${dir%/}
  if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git -C "$dir" branch --show-current)
    [[ -n $branch ]] || branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)
    jq -nc \
      --arg dir "$dir" \
      --arg branch "$branch" \
      --argjson changes "$(git -C "$dir" status --porcelain 2>/dev/null | wc -l)" \
      --argjson last "$(git -C "$dir" log -1 --format=%ct 2>/dev/null || echo 0)" \
      --arg subject "$(git -C "$dir" log -1 --format=%s 2>/dev/null)" \
      --arg counts "$(git -C "$dir" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)" \
      --arg remote "$(git -C "$dir" remote get-url origin 2>/dev/null)" \
      '{dir: $dir, git: true, branch: $branch, changes: $changes, last: $last, subject: $subject, counts: $counts, remote: $remote}'
  else
    jq -nc --arg dir "$dir" --argjson last "$(stat -c %Y "$dir")" '{dir: $dir, git: false, last: $last}'
  fi
done
