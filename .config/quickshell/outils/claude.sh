#!/usr/bin/env bash
# Données du tableau de bord Claude Code (claude.qml).
#   claude.sh list         {running: [...], recent: [...]} depuis ~/.claude
#   claude.sh focus <pid>  met au premier plan la fenêtre du terminal qui héberge ce processus

set -uo pipefail

readonly claude_dir=$HOME/.claude

list() {
  local running=() file pid
  for file in "$claude_dir"/sessions/*.json; do
    [[ -e $file ]] || continue
    pid=$(jq -r '.pid' "$file")
    [[ -d /proc/$pid ]] || continue
    running+=("$(jq -c '{sessionId, pid, cwd, name, status, statusUpdatedAt, startedAt, kind}' "$file")")
  done

  # Les 30 transcriptions les plus récentes : titre, dossier, branche et dernier message.
  local recent=()
  while IFS= read -r file; do
    local first title prompt
    first=$(grep -m 1 '"cwd":' "$file") || continue
    title=$(grep '"type":"ai-title"' "$file" | tail -n 1 | jq -r '.aiTitle // empty')
    prompt=$(grep '"type":"last-prompt"' "$file" | tail -n 1 | jq -r '.lastPrompt // empty' | head -c 300)
    recent+=("$(jq -c \
      --arg id "$(basename "$file" .jsonl)" \
      --arg title "$title" \
      --arg prompt "$prompt" \
      --argjson modified "$(stat -c %Y "$file")" \
      --argjson exists "$(jq -r '.cwd' <<<"$first" | { read -r dir; [[ -d $dir ]] && echo true || echo false; })" \
      '{sessionId: $id, cwd, branch: .gitBranch, title: $title, prompt: $prompt, modified: $modified, exists: $exists}' <<<"$first")")
  done < <(find "$claude_dir/projects" -maxdepth 2 -name '*.jsonl' -printf '%T@ %p\n' | sort -rn | head -n 30 | cut -d' ' -f2-)

  jq -nc --argjson running "[$(IFS=,; echo "${running[*]}")]" --argjson recent "[$(IFS=,; echo "${recent[*]}")]" \
    '{running: $running, recent: $recent}'
}

# Premier ancêtre du processus qui possède une fenêtre Hyprland.
focus() {
  local pid=$1 clients window
  clients=$(hyprctl clients -j)
  while [[ -n $pid && $pid -gt 1 ]]; do
    window=$(jq -r --argjson pid "$pid" 'first(.[] | select(.pid == $pid) | .address) // empty' <<<"$clients")
    if [[ -n $window ]]; then
      hyprctl dispatch "hl.dsp.focus({ window = \"address:$window\" })" >/dev/null
      return 0
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
  return 1
}

case ${1:-} in
  list) list ;;
  focus) focus "${2:?pid manquant}" ;;
  *)
    printf 'usage : claude.sh list | focus <pid>\n' >&2
    exit 64
    ;;
esac
