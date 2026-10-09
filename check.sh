#!/usr/bin/env bash

set -u

failures=0

pass() {
  printf '[ OK ] %s\n' "$*"
}

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  failures=$((failures + 1))
}

check_command() {
  local command_name=$1

  if command -v "$command_name" >/dev/null 2>&1; then
    pass "$command_name installé"
  else
    fail "$command_name introuvable"
  fi
}

check_command caelestia
check_command qs
check_command cliphist
check_command fuzzel

if command -v qs >/dev/null 2>&1 && qs -c caelestia list -j 2>/dev/null | grep -q '"pid"'; then
  pass "Caelestia en cours d'exécution"
else
  fail 'Caelestia ne tourne pas'
fi

if pgrep -x noctalia >/dev/null; then
  fail 'Noctalia tourne encore en parallèle de Caelestia'
else
  pass 'Noctalia arrêté'
fi

if systemctl --user is-active --quiet elephant.service 2>/dev/null; then
  fail 'elephant.service encore actif'
else
  pass 'elephant.service inactif'
fi

for type in text image; do
  if pgrep -f "wl-paste --type $type --watch cliphist store" >/dev/null; then
    pass "historique du presse-papiers ($type) actif"
  else
    fail "historique du presse-papiers ($type) inactif"
  fi
done

if [[ -f "$HOME/.config/caelestia/shell.json" ]]; then
  pass 'configuration Caelestia présente'
else
  fail "configuration absente : $HOME/.config/caelestia/shell.json"
fi

kitty_theme="$HOME/.config/kitty/themes/caelestia.conf"
if [[ -s "$kitty_theme" ]] && ! grep -Fq '{{' "$kitty_theme" &&
  grep -Fxq 'include themes/caelestia.conf' "$HOME/.config/kitty/kitty.conf" 2>/dev/null; then
  pass 'thème kitty généré par Caelestia'
else
  fail "thème kitty absent, non résolu ou non inclus : $kitty_theme"
fi

installer="$HOME/.local/bin/install-arch-package"
if [[ -f "$installer" && -x "$installer" ]]; then
  pass 'install-arch-package exécutable'
else
  fail "script absent ou non exécutable : $installer"
fi

for outil in inactivite capture raccourcis presse-papiers emojis; do
  if [[ -f "$HOME/.config/quickshell/outils/$outil.qml" ]]; then
    pass "fenêtre $outil présente"
  else
    fail "fenêtre absente : $HOME/.config/quickshell/outils/$outil.qml"
  fi
done

for script in qs-outil capture; do
  if [[ -x "$HOME/.local/bin/$script" ]]; then
    pass "$script exécutable"
  else
    fail "script absent ou non exécutable : $HOME/.local/bin/$script"
  fi
done

binds_file="$HOME/.config/hypr/config/binds.lua"
if [[ -f "$binds_file" ]] && grep -Eq 'hl\.bind\(mainMod \.\. " \+ Space".*caelestia:launcher' "$binds_file"; then
  pass 'bind Super+Space vers le launcher Caelestia'
else
  fail "bind Super+Space vers Caelestia absent : $binds_file"
fi

if grep -rqiE 'noctalia|walker' "$HOME/.config/hypr" --include='*.lua'; then
  fail 'références à Noctalia ou Walker restantes dans la config Hyprland'
else
  pass 'config Hyprland sans Noctalia ni Walker'
fi

if (( failures == 0 )); then
  printf '\nTous les contrôles sont passés.\n'
  exit 0
fi

printf '\n%d contrôle(s) en échec.\n' "$failures" >&2
exit 1
