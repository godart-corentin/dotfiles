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

check_provider() {
  local provider=$1

  if grep -Fxq "$provider" <<< "$providers"; then
    pass "provider Elephant : $provider"
  else
    fail "provider Elephant absent : $provider"
  fi
}

check_command walker
check_command elephant

if command -v systemctl >/dev/null 2>&1 && systemctl --user is-active --quiet elephant.service; then
  pass 'elephant.service actif'
else
  fail 'elephant.service inactif ou inaccessible'
fi

providers=""
if command -v elephant >/dev/null 2>&1; then
  providers=$(elephant listproviders 2>/dev/null || true)
fi
check_provider desktopapplications
check_provider archlinuxpkgs

generated_style="$HOME/.config/walker/themes/noctalia/style.css"
if [[ -s "$generated_style" ]] && ! grep -Fq '{{' "$generated_style"; then
  pass 'template Walker généré'
else
  fail "template Walker absent, vide ou non résolu : $generated_style"
fi

installer="$HOME/.local/bin/install-arch-package"
if [[ -f "$installer" && -x "$installer" ]]; then
  pass 'install-arch-package exécutable'
else
  fail "script absent ou non exécutable : $installer"
fi

binds_file="$HOME/.config/hypr/config/binds.lua"
if [[ -f "$binds_file" ]] && grep -Eq 'hl\.bind\(mainMod \.\. " \+ Space".*walker' "$binds_file"; then
  pass 'bind Super+Space vers Walker'
else
  fail "bind Super+Space vers Walker absent : $binds_file"
fi

hyprland_file="$HOME/.config/hypr/hyprland.lua"
if [[ -f "$hyprland_file" ]] && awk '
  /hl\.layer_rule/ { in_rule=1; namespace=0; blur=0 }
  in_rule && /namespace[[:space:]]*=[[:space:]]*"walker"/ { namespace=1 }
  in_rule && /blur[[:space:]]*=[[:space:]]*true/ { blur=1 }
  in_rule && /^[[:space:]]*}\)/ {
    if (namespace && blur) found=1
    in_rule=0
  }
  END { exit(found ? 0 : 1) }
' "$hyprland_file"; then
  pass 'règle blur Walker'
else
  fail "règle blur Walker absente : $hyprland_file"
fi

if (( failures == 0 )); then
  printf '\nTous les contrôles sont passés.\n'
  exit 0
fi

printf '\n%d contrôle(s) en échec.\n' "$failures" >&2
exit 1
