#!/usr/bin/env bash
# Ports TCP en écoute pour ports.qml, en un tableau JSON trié par port.
# Le processus n'est connu que pour les tiens : ss ne montre pas les autres sans être root.
# Usage : ports.sh <dossier des projets>

set -uo pipefail

readonly workspace=${1:-$HOME/workspace}

ss -ltnpH | while read -r _ _ _ local _ process; do
  pid=$(grep -oP 'pid=\K[0-9]+' <<<"$process" | head -n 1)
  cwd= command= uptime=0
  if [[ -n $pid && -r /proc/$pid/cmdline ]]; then
    cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null)
    command=$(tr '\0' ' ' <"/proc/$pid/cmdline")
    uptime=$(ps -o etimes= -p "$pid" | tr -d ' ')
  fi
  project=
  [[ $cwd == "$workspace"/* ]] && project=${cwd#"$workspace"/} && project=${project%%/*}
  jq -nc \
    --argjson port "${local##*:}" \
    --arg address "${local%:*}" \
    --arg pid "$pid" \
    --arg name "$(grep -oP '\(\("\K[^"]+' <<<"$process" | head -n 1)" \
    --arg command "${command% }" \
    --arg cwd "$cwd" \
    --arg project "$project" \
    --argjson uptime "${uptime:-0}" \
    '{port: $port, address: $address, pid: ($pid | if . == "" then null else tonumber end), name: $name,
      command: $command, cwd: $cwd, project: $project, uptime: $uptime}'
done | jq -sc 'group_by(.port) | map(.[0] + {addresses: (map(.address) | unique)} | del(.address))'
